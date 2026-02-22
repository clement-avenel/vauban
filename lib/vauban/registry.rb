# frozen_string_literal: true

module Vauban
  module Registry
    module_function

    def policies
      policies_store.dup.freeze
    end

    def resources
      resources_store.dup.freeze
    end

    def reset!
      @policies = {}
      @resources = []
      @discovered = nil
    end

    def register(policy_class)
      resource_class = policy_class.resource_class
      raise ArgumentError, "Policy #{policy_class.name} must declare `resource SomeModel`" unless resource_class

      policies_store[resource_class] = policy_class
      resources_store << resource_class unless resources_store.include?(resource_class)
      policy_class
    end

    def policy_for(resource_class)
      return nil unless resource_class

      cache_key = Cache.key_for_policy(resource_class)
      Cache.fetch(cache_key) do
        policies_store[resource_class] ||
          find_policy_by_inheritance(resource_class) ||
          try_autoload(resource_class)
      end
    end

    def discover_and_register
      @discovered ||= {}

      policy_files.each { |file| load_policy_file(file) }

      ObjectSpace.each_object(Class) do |klass|
        next unless klass < Policy && klass != Policy && klass.resource_class
        next if @discovered.key?(klass)

        register(klass) unless policies_store[klass.resource_class]
        @discovered[klass] = true
      end
    end

    # --- Private ---

    def policies_store
      @policies ||= {}
    end

    def resources_store
      @resources ||= []
    end

    def find_policy_by_inheritance(resource_class)
      return nil unless resource_class.respond_to?(:superclass)

      parent = resource_class.superclass
      return nil if parent.nil? || parent == Object
      return nil if defined?(ActiveRecord::Base) && parent == ActiveRecord::Base

      policy_for(parent)
    end

    def try_autoload(resource_class)
      return nil unless resource_class.respond_to?(:name) && resource_class.name

      "#{resource_class.name}Policy".constantize
      discover_and_register
      policies_store[resource_class] || find_policy_by_inheritance(resource_class)
    rescue NameError
      nil
    end

    def policy_files
      base = defined?(Rails) && Rails.respond_to?(:root) ? Rails.root.to_s : Dir.pwd
      Vauban.config.policy_paths.flat_map { |pattern| Dir[File.join(base, pattern)] }
    end

    def load_policy_file(file)
      require file
    rescue LoadError
      base = defined?(Rails) && Rails.respond_to?(:root) ? Rails.root.to_s : Dir.pwd
      class_name = file.sub("#{base}/", "").sub(".rb", "").split("/").map(&:camelize).join("::")
      begin
        class_name.constantize
      rescue NameError
        nil
      end
    end

    private_class_method :policies_store, :resources_store,
                         :find_policy_by_inheritance, :try_autoload, :policy_files, :load_policy_file
  end
end
