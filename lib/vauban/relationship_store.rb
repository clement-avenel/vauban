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
  end
end
