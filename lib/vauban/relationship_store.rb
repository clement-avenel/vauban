# frozen_string_literal: true

module Vauban
  # Public API for managing relationship tuples. Extended onto Vauban so
  # callers can use Vauban.grant!, Vauban.revoke!, Vauban.relation?, etc.
  #
  # Relationship tuples are the core data model for ReBAC: each tuple records
  # a fact like "user 42 is an editor of document 7". Permissions are then
  # derived from these relationships via the policy schema.
  #
  # Requires ActiveRecord to be loaded. The Relationship model is loaded
  # on first use to avoid boot-order issues.
  module RelationshipStore
    # Creates a relationship tuple (subject, relation, object).
    # No-ops if the exact tuple already exists.
    #
    # Automatically clears cached permissions for both the subject and object,
    # since adding a relationship may change authorization outcomes.
    #
    # @param subject [ActiveRecord::Base] the subject (e.g. a User or Team)
    # @param relation [Symbol, String] the relation name (e.g. :editor, :member)
    # @param object [ActiveRecord::Base] the object (e.g. a Document or Project)
    # @return [Vauban::Relationship] the created or existing relationship
    def grant!(subject, relation, object)
      rel = relationship_model.create_or_find_by!(
        subject_type: subject.class.name,
        subject_id:   subject.id,
        relation:     relation.to_s,
        object_type:  object.class.name,
        object_id:    object.id
      )
      invalidate_relationship_cache(subject, object)
      rel
    end

    # Removes a relationship tuple. No-ops if the tuple doesn't exist.
    #
    # @param subject [ActiveRecord::Base]
    # @param relation [Symbol, String]
    # @param object [ActiveRecord::Base]
    # @return [Integer] number of deleted rows (0 or 1)
    def revoke!(subject, relation, object)
      count = relationship_model.between(subject, object).with_relation(relation).delete_all
      invalidate_relationship_cache(subject, object) if count > 0
      count
    end

    # Checks whether a specific relationship tuple exists.
    #
    # @param subject [ActiveRecord::Base]
    # @param relation [Symbol, String]
    # @param object [ActiveRecord::Base]
    # @return [Boolean]
    def relation?(subject, relation, object)
      relationship_model.between(subject, object).with_relation(relation).exists?
    end

    # Checks whether the subject has the given relation to the object, using the
    # policy's relation schema (implied relations + optional via: indirect paths).
    # E.g. has_relation?(user, :viewer, doc) is true if (user, viewer|editor|owner, doc) or
    # (user, member, team) and (team, viewer, doc). Falls back to direct check when no policy/schema.
    #
    # @param subject [ActiveRecord::Base]
    # @param relation [Symbol, String]
    # @param object [ActiveRecord::Base]
    # @return [Boolean]
    def has_relation?(subject, relation, object)
      return true if has_direct_relation?(subject, relation, object)

      policy_class = Registry.policy_for(object.class)
      via_rules = policy_class&.relation_via_for(relation) || {}
      via_rules.each do |via_rel, via_type|
        intermediates = objects_with(subject, via_rel, object_type: via_type)
        return true if intermediates.any? { |rec| has_direct_relation?(rec.object, relation, object) }
      end
      false
    end

    # Returns all object ids the subject has the given relation to (direct + via).
    # Used by scope generation for accessible_by. Result is cached by (subject, relation, object_type)
    # and invalidated when relationships are granted or revoked.
    #
    # @param subject [ActiveRecord::Base]
    # @param relation [Symbol, String]
    # @param object_type [Class]
    # @return [Array<Integer>]
    def object_ids_for_relation(subject, relation, object_type)
      cache_key = Cache.key_for_relation_scope(subject, relation, object_type)
      Cache.fetch(cache_key) do
        compute_object_ids_for_relation(subject, relation, object_type)
      end
    end

    # Returns all objects the subject has the given relation to, including via
    # implied relations from the policy schema (e.g. asking for :viewer includes
    # objects where subject is :editor or :owner). Falls back to objects_with
    # when no policy or schema is present.
    #
    # @param subject [ActiveRecord::Base]
    # @param relation [Symbol, String]
    # @param object_type [Class, nil] optional filter by object class
    # @return [ActiveRecord::Relation<Vauban::Relationship>]
    def objects_with_effective(subject, relation, object_type: nil)
      policy_class = object_type ? Registry.policy_for(object_type) : nil
      relations_to_check = policy_class&.effective_relations(relation) || [ relation.to_sym ]
      scope = relationship_model.for_subject(subject).with_any_relation(relations_to_check)
      scope = scope.where(object_type: object_type.name) if object_type
      scope
    end

    # Returns all relation names between a subject and an object.
    #
    # @param subject [ActiveRecord::Base]
    # @param object [ActiveRecord::Base]
    # @return [Array<Symbol>]
    def relations_between(subject, object)
      relationship_model.between(subject, object).distinct.pluck(:relation).map(&:to_sym)
    end

    # Returns all subjects that hold a given relation to an object.
    #
    #   Vauban.subjects_with(:editor, document)
    #   # => [#<Vauban::Relationship ...>, ...]
    #
    # @param relation [Symbol, String]
    # @param object [ActiveRecord::Base]
    # @param subject_type [Class, nil] optional filter by subject class
    # @return [ActiveRecord::Relation<Vauban::Relationship>]
    def subjects_with(relation, object, subject_type: nil)
      scope = relationship_model.for_object(object).with_relation(relation)
      scope = scope.where(subject_type: subject_type.name) if subject_type
      scope
    end

    # Returns all objects that a subject holds a given relation to.
    #
    #   Vauban.objects_with(user, :editor)
    #   # => [#<Vauban::Relationship ...>, ...]
    #
    # @param subject [ActiveRecord::Base]
    # @param relation [Symbol, String]
    # @param object_type [Class, nil] optional filter by object class
    # @return [ActiveRecord::Relation<Vauban::Relationship>]
    def objects_with(subject, relation, object_type: nil)
      scope = relationship_model.for_subject(subject).with_relation(relation)
      scope = scope.where(object_type: object_type.name) if object_type
      scope
    end

    # Removes all relationships for a given subject, object, or both.
    # At least one of subject or object must be provided.
    #
    # @param subject [ActiveRecord::Base, nil]
    # @param object [ActiveRecord::Base, nil]
    # @return [Integer] number of deleted rows
    # @raise [ArgumentError] if neither subject nor object is provided
    def revoke_all!(subject: nil, object: nil)
      raise ArgumentError, "must provide at least one of subject: or object:" unless subject || object

      scope = relationship_model.all
      scope = scope.for_subject(subject) if subject
      scope = scope.for_object(object) if object
      count = scope.delete_all
      invalidate_relationship_cache(subject, object) if count > 0
      count
    end

    private

    def has_direct_relation?(subject, relation, object)
      policy_class = Registry.policy_for(object.class)
      relations_to_check = policy_class&.effective_relations(relation) || [ relation.to_sym ]
      relations_to_check.any? { |r| relation?(subject, r, object) }
    end

    def relationship_model
      unless defined?(Vauban::Relationship)
        require "active_record" unless defined?(ActiveRecord::Base)
        require "vauban/relationship"
      end
      Vauban::Relationship
    end

    def invalidate_relationship_cache(subject, object)
      Cache.clear_for_user(subject) if subject
      Cache.clear_for_resource(object) if object
    end

    def compute_object_ids_for_relation(subject, relation, object_type)
      policy_class = Registry.policy_for(object_type)
      ids = objects_with_effective(subject, relation, object_type: object_type).distinct.pluck(:object_id)

      via_rules = policy_class&.relation_via_for(relation) || {}
      via_rules.each do |via_rel, via_type|
        intermediate_ids = objects_with(subject, via_rel, object_type: via_type).distinct.pluck(:object_id)
        next if intermediate_ids.empty?

        relations_to_check = policy_class.effective_relations(relation)
        ids.concat(
          relationship_model
            .where(subject_type: via_type.name, subject_id: intermediate_ids, object_type: object_type.name)
            .with_any_relation(relations_to_check)
            .distinct
            .pluck(:object_id)
        )
      end

      ids.uniq
    end
  end
end
