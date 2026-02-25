# frozen_string_literal: true

module Vauban
  # Path B: declarative hash conditions that work as both runtime checks and SQL scope generators.
  # Define permission rules once with +allow_where+; Vauban uses them for both +can?+ and +accessible_by+.
  #
  # @see Policy#permission allow_where in permission DSL
  module AllowWhere
    class << self
      # Returns true if the record's attributes (and optional nested association attributes) match the condition hash.
      # Used for runtime +can?+ checks when the permission uses +allow_where+.
      #
      # @param record [Object] the resource (must respond to #send for each hash key)
      # @param hash [Hash] condition hash; values may be scalars, arrays (IN), or nested hashes (association)
      # @return [Boolean]
      def record_matches_hash?(record, hash)
        return true if hash.nil? || hash.empty?

        hash.all? do |key, value|
          key = key.to_sym
          return false unless record.respond_to?(key)

          attr_value = record.public_send(key)

          if value.is_a?(Hash)
            return false if attr_value.nil?
            record_matches_hash?(attr_value, value)
          elsif value.is_a?(Array)
            value.include?(attr_value)
          else
            attr_value == value
          end
        end
      end

      # Builds an ActiveRecord::Relation from an array of condition hashes (OR between hashes).
      # Handles flat attributes and one level of association nesting (e.g. +owner: { id: user.id }+).
      # Returns +model_class.none+ when hashes is empty; falls back to +model_class.all+ when model doesn't support +where+.
      #
      # @param model_class [Class] typically an ActiveRecord::Base subclass
      # @param hashes [Array<Hash>] condition hashes from +allow_where+ blocks (user/context already applied)
      # @return [ActiveRecord::Relation, Object] scoped relation or model_class.all when not scopeable
      def build_scope(model_class, hashes)
        hashes = Array(hashes).compact.reject(&:empty?)
        return model_class.all if hashes.empty?
        return model_class.all unless model_class.respond_to?(:where)

        relations = hashes.map { |h| relation_for_hash(model_class, h) }
        base = relations.shift
        relations.each { |rel| base = base.or(rel) }
        base.distinct
      end

      private

      def relation_for_hash(model_class, hash)
        scope = model_class.all
        hash.each do |key, value|
          key = key.to_sym
          if value.is_a?(Hash)
            nested_assocs = value.select { |_, v| v.is_a?(Hash) }
            join_arg = if nested_assocs.empty?
              key
            elsif nested_assocs.size == 1
              { key => nested_assocs.keys.first }
            else
              { key => nested_assocs.keys }
            end
            scope = scope.joins(join_arg).where(key => value)
          else
            scope = scope.where(key => value)
          end
        end
        scope
      end
    end
  end
end
