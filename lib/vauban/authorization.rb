# frozen_string_literal: true

module Vauban
  # Public authorization API. Extended onto Vauban (Vauban.authorize, Vauban.can?, etc.).
  module Authorization
    PRELOAD_ASSOCIATION_NAMES = %w[owner user collaborator collaborators team members organization].freeze

    def authorize(user, action, resource, context: {})
      policy_class = Registry.policy_for(resource.class)
      raise PolicyNotFound.new(resource.class, context: context) unless policy_class

      return true if can?(user, action, resource, context: context)

      raise Unauthorized.new(
        user, action, resource,
        available_permissions: policy_class.available_permissions,
        context: context
      )
    end

    def can?(user, action, resource, context: {})
      cache_key = Cache.key_for_permission(user, action, resource, context: context)
      Cache.fetch(cache_key) do
        with_policy(user, resource) { |policy| policy.allowed?(action, resource, context: context) } || false
      end
    rescue StandardError => e
      log_authorization_error(e, action: action, resource: resource)
      false
    end

    def all_permissions(user, resource, context: {})
      cache_key = Cache.key_for_all_permissions(user, resource, context: context)
      Cache.fetch(cache_key) do
        with_policy(user, resource) { |policy| policy.all_permissions(resource, context: context) } || {}
      end
    rescue StandardError => e
      log_authorization_error(e, resource: resource)
      {}
    end

    def batch_permissions(user, resources, context: {})
      return {} if resources.empty?

      policy_classes = resources.map(&:class).uniq.to_h { |klass| [ klass, Registry.policy_for(klass) ] }

      preload_associations(resources)

      cached, uncached = partition_batch_by_cache(user, resources, context)
      cached.merge(compute_uncached_permissions(user, uncached, policy_classes, context))
    end

    def accessible_by(user, action, resource_class, context: {})
      policy_class = Registry.policy_for(resource_class)
      raise PolicyNotFound.new(resource_class, context: context) unless policy_class

      policy_class.instance_for(user).scope(action, context: context)
    end

    def clear_cache!
      Cache.clear
    end

    def clear_cache_for_resource!(resource)
      Cache.clear_for_resource(resource)
    end

    def clear_cache_for_user!(user)
      Cache.clear_for_user(user)
    end

    def clear_policy_instance_cache!
      Policy.clear_instance_cache!
    end

    private

    def with_policy(user, resource)
      policy_class = Registry.policy_for(resource.class)
      return nil unless policy_class

      yield policy_class.instance_for(user)
    end

    def log_authorization_error(error, action: nil, resource: nil)
      ErrorHandler.handle_authorization_error(
        error,
        context: { action: action, resource: resource&.class&.name }.compact
      )
    end

    # --- Batch helpers ---

    def partition_batch_by_cache(user, resources, context)
      keys = resources.to_h { |r| [ r, Cache.key_for_all_permissions(user, r, context: context) ] }
      cached = {}
      uncached = []
      store = Vauban.config.cache_store

      if store&.respond_to?(:read_multi)
        hits = store.read_multi(*keys.values)
        keys.each { |resource, key| hits.key?(key) ? cached[resource] = hits[key] : uncached << [ resource, key ] }
      else
        keys.each { |resource, key| uncached << [ resource, key ] }
      end

      [ cached, uncached ]
    end

    def compute_uncached_permissions(user, uncached, policy_classes, context)
      uncached.to_h do |resource, cache_key|
        permissions = Cache.fetch(cache_key) do
          policy_class = policy_classes[resource.class]
          policy_class ? policy_class.instance_for(user).all_permissions(resource, context: context) : {}
        end
        [ resource, permissions ]
      end
    end

    def preload_associations(resources)
      return unless defined?(ActiveRecord::Base)

      resources.group_by(&:class).each do |klass, records|
        next unless klass < ActiveRecord::Base

        associations = detect_preload_associations(klass)
        next if associations.empty?

        ActiveRecord::Associations::Preloader.new(records: records, associations: associations).call
      end
    rescue StandardError => e
      ErrorHandler.handle_non_critical_error(e, operation: "association preloading")
    end

    def detect_preload_associations(klass)
      found = []
      PRELOAD_ASSOCIATION_NAMES.each do |name|
        found << name.to_sym if klass.reflect_on_association(name.to_sym) || klass.reflect_on_association(name.pluralize.to_sym)
      end
      klass.reflect_on_all_associations(:belongs_to).each { |ref| found << ref.name unless found.include?(ref.name) }
      found
    end
  end
end
