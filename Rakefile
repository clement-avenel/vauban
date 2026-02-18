# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

# Unit tests (no Rails)
RSpec::Core::RakeTask.new(:spec_unit) do |t|
  t.pattern = "spec/vauban/**/*_spec.rb"
end

# Integration tests (requires Rails/dummy app)
RSpec::Core::RakeTask.new(:spec_integration) do |t|
  t.pattern = "spec/integration/**/*_spec.rb"
end

task default: :spec
