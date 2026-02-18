# frozen_string_literal: true

require "rails/generators"

module Vauban
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def create_initializer
        copy_file "initializer.rb", "config/initializers/vauban.rb"
      end

      def create_example_policy
        copy_file "example_policy.rb", "app/policies/document_policy.rb"
      end
    end
  end
end
