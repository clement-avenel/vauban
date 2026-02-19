# frozen_string_literal: true

module Vauban
  # Preloads associations for ActiveRecord resources to prevent N+1 queries
  # when checking permissions on multiple resources
  class AssociationPreloader
    # Common association names that are often used in permission checks
    COMMON_ASSOCIATION_NAMES = %w[owner user collaborator collaborators team members organization].freeze

    def initialize(resources)
      @resources = resources
    end

    def call
      return unless active_record_available?
      return if @resources.empty?

      resources_by_class = @resources.group_by(&:class)

      resources_by_class.each do |resource_class, class_resources|
        # Only preload for ActiveRecord models
        next unless resource_class < ActiveRecord::Base

        # Filter to only ActiveRecord instances (not classes)
        ar_instances = class_resources.select { |r| r.is_a?(ActiveRecord::Base) }
        next if ar_instances.empty?

        # Common association names that are often used in permission checks
        # Users can override this behavior by preloading associations themselves
        common_associations = detect_associations(resource_class)

        if common_associations.any?
          # Use ActiveRecord's preloader API (Rails 6+)
          ActiveRecord::Associations::Preloader.new(
            records: ar_instances,
            associations: common_associations
          ).call
        end
      end
    rescue StandardError => e
      # If preloading fails, log but don't fail the authorization check
      # This is a performance optimization, not a critical feature
      ErrorHandler.handle_non_critical_error(e, operation: "association preloading")
    end

    private

    def detect_associations(resource_class)
      associations = []

      # Check for common relationship patterns
      COMMON_ASSOCIATION_NAMES.each do |name|
        if resource_class.reflect_on_association(name.to_sym) ||
           resource_class.reflect_on_association(name.pluralize.to_sym)
          associations << name.to_sym
        end
      end

      # Also check for belongs_to associations (commonly used in permission checks)
      resource_class.reflect_on_all_associations(:belongs_to).each do |reflection|
        associations << reflection.name unless associations.include?(reflection.name)
      end

      associations
    end

    def active_record_available?
      defined?(ActiveRecord) && defined?(ActiveRecord::Base)
    end
  end
end
