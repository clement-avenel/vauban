# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vauban::ErrorHandler do
  let(:mock_logger) { double("Logger", error: nil, warn: nil) }
  let(:error) { StandardError.new("Test error") }

  before do
    allow(::Rails).to receive(:logger).and_return(mock_logger) if defined?(Rails)
    allow(::Rails).to receive(:respond_to?).with(:logger).and_return(true) if defined?(Rails)
  end

  describe ".handle_authorization_error" do
    it "returns false" do
      result = described_class.handle_authorization_error(error)
      expect(result).to be false
    end

    it "logs error when Rails logger is available" do
      if defined?(Rails)
        expect(mock_logger).to receive(:error).with(include("Vauban error"))
        described_class.handle_authorization_error(error)
      end
    end

    it "includes context in log message" do
      if defined?(Rails)
        expect(mock_logger).to receive(:error).with(include("Context:"))
        described_class.handle_authorization_error(error, context: { action: :view })
      end
    end
  end

  describe ".handle_non_critical_error" do
    it "executes fallback block" do
      result = described_class.handle_non_critical_error(error, operation: "test") { "fallback" }
      expect(result).to eq("fallback")
    end

    it "returns nil when no block given" do
      result = described_class.handle_non_critical_error(error, operation: "test")
      expect(result).to be_nil
    end

    it "logs warning when Rails logger is available" do
      if defined?(Rails)
        expect(mock_logger).to receive(:warn).with(include("Vauban error in test"))
        described_class.handle_non_critical_error(error, operation: "test")
      end
    end
  end

  describe ".handle_cache_error" do
    it "executes fallback block" do
      result = described_class.handle_cache_error(error, key: "test:key") { "cached" }
      expect(result).to eq("cached")
    end

    it "returns nil when no block given" do
      result = described_class.handle_cache_error(error, key: "test:key")
      expect(result).to be_nil
    end

    it "logs cache error when Rails logger is available" do
      if defined?(Rails)
        expect(mock_logger).to receive(:error).with(include("cache error for key 'test:key'"))
        described_class.handle_cache_error(error, key: "test:key")
      end
    end
  end

  describe ".handle_permission_error" do
    let(:resource) { double("Resource", id: 1, class: double(name: "Document")) }
    let(:user) { double("User", id: 1, class: double(name: "User")) }
    let(:policy_class) { double("PolicyClass", name: "DocumentPolicy") }

    it "returns false" do
      result = described_class.handle_permission_error(
        error,
        permission: :view,
        rule_type: :allow
      )
      expect(result).to be false
    end

    it "logs permission error when Rails logger is available" do
      if defined?(Rails)
        expect(mock_logger).to receive(:error).with(include("permission evaluation error"))
        described_class.handle_permission_error(
          error,
          permission: :view,
          rule_type: :allow,
          context: { resource: resource, user: user, policy: policy_class }
        )
      end
    end

    it "includes permission and rule type in log" do
      if defined?(Rails)
        expect(mock_logger).to receive(:error).with(include("Permission: :view").and(include("Rule type: allow")))
        described_class.handle_permission_error(
          error,
          permission: :view,
          rule_type: :allow
        )
      end
    end
  end
end
