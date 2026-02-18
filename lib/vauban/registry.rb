# frozen_string_literal: true

module Vauban
  class Registry
    class << self
      attr_reader :policies, :resources

      def initialize_registry
        @policies = {}
        @resources = []
      end

      def register(policy_class, package: nil, depends_on: [])
        resource_class = policy_class.resource_class
        raise ArgumentError, "Policy must define resource_class" unless resource_class

        @policies ||= {}
        @resources ||= []

        @policies[resource_class] = policy_class
        @resources << resource_class unless @resources.include?(resource_class)

        policy_class.package = package if package
        policy_class.depends_on = depends_on if depends_on.any?

        policy_class
      end

      def policy_for(resource_class)
        @policies ||= {}
        return nil unless resource_class

        # Cache policy lookup (but not lazy discovery results)
        cache_key = Vauban::Cache.key_for_policy(resource_class)

        Vauban::Cache.fetch(cache_key) do
          result = @policies[resource_class] || find_policy_by_inheritance(resource_class)

          # If policy not found, try lazy discovery (for autoloading in development)
          if result.nil? && resource_class.respond_to?(:name) && resource_class.name
            # Try to trigger autoloading by constantizing the expected policy class name
            policy_class_name = "#{resource_class.name}Policy"
            begin
              policy_class_name.constantize
              # Re-run discovery to register the newly loaded policy
              discover_and_register
              result = @policies[resource_class] || find_policy_by_inheritance(resource_class)
            rescue NameError
              # Policy class doesn't exist, return nil
            end
          end

          result
        end
      end

      def discover_and_register
        initialize_registry unless @policies

        # Build absolute paths for policy files
        base_path = if defined?(Rails) && Rails.respond_to?(:root)
          Rails.root.to_s
        else
          Dir.pwd
        end

        # Load policy files - in development, Rails autoloading will handle it
        # but we still need to trigger loading by requiring or constantizing
        Vauban.config.policy_paths.each do |path_pattern|
          full_path = File.join(base_path, path_pattern)
          Dir[full_path].each do |file|
            # Try to load the file - Rails autoloading will handle it in dev
            begin
              require file
            rescue LoadError
              # If require fails, try to trigger autoload by constantizing
              relative_path = file.sub("#{base_path}/", "").sub(".rb", "")
              class_name = relative_path.split("/").map(&:camelize).join("::")
              begin
                class_name.constantize
              rescue NameError
                # Ignore if class doesn't exist yet
              end
            end
          end
        end

        # Auto-register all policies that inherit from Vauban::Policy
        ObjectSpace.each_object(Class) do |klass|
          if klass < Policy && klass != Policy && klass.resource_class
            register(klass) unless @policies[klass.resource_class]
          end
        end
      end

      private

      def find_policy_by_inheritance(resource_class)
        # Try to find policy for parent class
        return nil unless resource_class && resource_class.respond_to?(:superclass)

        parent_class = resource_class.superclass
        return nil if parent_class.nil? || parent_class == Object

        # Check for ActiveRecord::Base if ActiveRecord is loaded
        if defined?(ActiveRecord::Base) && parent_class == ActiveRecord::Base
          return nil
        end

        policy_for(parent_class)
      end
    end

    initialize_registry
  end
end
