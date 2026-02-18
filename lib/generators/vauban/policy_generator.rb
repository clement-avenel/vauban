# frozen_string_literal: true

require "rails/generators"

module Vauban
  module Generators
    class PolicyGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      def create_policy
        template "policy.rb.erb", File.join("app/policies", class_path, "#{file_name}_policy.rb")
      end

      private

      def resource_class_name
        class_name
      end
    end
  end
end
