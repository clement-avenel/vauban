# frozen_string_literal: true

require "set"

module Vauban
  class Registry
    class << self
      attr_reader :policies, :resources

      def initialize_registry
        @policies = {}
        @resources = []
      end

      def register(policy_class)
        resource_class = policy_class.resource_class
        raise ArgumentError, "Policy #{policy_class.name} must declare `resource SomeModel`" unless resource_class

        @policies[resource_class] = policy_class
        @resources << resource_class unless @resources.include?(resource_class)
        policy_class
      end

      def policy_for(resource_class)
        return nil unless resource_class

        cache_key = Cache.key_for_policy(resource_class)
        Cache.fetch(cache_key) do
          @policies[resource_class] ||
            find_policy_by_inheritance(resource_class) ||
            try_autoload(resource_class)
        end
      end

      def discover_and_register
        @discovered ||= Set.new

        policy_files.each { |file| load_policy_file(file) }

        ObjectSpace.each_object(Class) do |klass|
          next unless klass < Policy && klass != Policy && klass.resource_class
          next if @discovered.include?(klass)

          register(klass) unless @policies[klass.resource_class]
          @discovered.add(klass)
        end
      end

      private

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
        @policies[resource_class] || find_policy_by_inheritance(resource_class)
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
    end

    initialize_registry
  end
end
