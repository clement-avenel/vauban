# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vauban::ErrorHandler do
  let(:mock_logger) { double("Logger", error: nil, warn: nil) }
  let(:error) { StandardError.new("Test error") }

  before do
    if defined?(Rails)
      allow(::Rails).to receive(:logger).and_return(mock_logger)
      allow(::Rails).to receive(:respond_to?).with(:logger).and_return(true)
    end
  end

  describe ".handle_authorization_error" do
    it "returns false" do
      expect(described_class.handle_authorization_error(error)).to be false
    end

    it "logs error when Rails logger is available" do
      next unless defined?(Rails)
      expect(mock_logger).to receive(:error).with(include("Vauban"))
      described_class.handle_authorization_error(error)
    end

    it "includes context in log message" do
      next unless defined?(Rails)
      expect(mock_logger).to receive(:error).with(include("action"))
      described_class.handle_authorization_error(error, context: { action: :view })
    end
  end

  describe ".handle_non_critical_error" do
    it "executes fallback block" do
      result = described_class.handle_non_critical_error(error, operation: "test") { "fallback" }
      expect(result).to eq("fallback")
    end

    it "returns nil when no block given" do
      expect(described_class.handle_non_critical_error(error, operation: "test")).to be_nil
    end

    it "logs warning when Rails logger is available" do
      next unless defined?(Rails)
      expect(mock_logger).to receive(:warn).with(include("test"))
      described_class.handle_non_critical_error(error, operation: "test")
    end
  end

  describe ".handle_cache_error" do
    it "executes fallback block" do
      result = described_class.handle_cache_error(error, key: "test:key") { "cached" }
      expect(result).to eq("cached")
    end

    it "returns nil when no block given" do
      expect(described_class.handle_cache_error(error, key: "test:key")).to be_nil
    end

    it "logs cache error when Rails logger is available" do
      next unless defined?(Rails)
      expect(mock_logger).to receive(:error).with(include("test:key"))
      described_class.handle_cache_error(error, key: "test:key")
    end
  end

  describe ".handle_permission_error" do
    let(:resource) { double("Resource", id: 1, class: double(name: "Document")) }
    let(:user) { double("User", id: 1, class: double(name: "User")) }
    let(:policy) { double("Policy", class: double(name: "DocumentPolicy")) }

    it "returns false" do
      result = described_class.handle_permission_error(error, permission: :view, rule_type: :allow)
      expect(result).to be false
    end

    it "logs permission error when Rails logger is available" do
      next unless defined?(Rails)
      expect(mock_logger).to receive(:error).with(include(":view").and(include("allow")))
      described_class.handle_permission_error(
        error, permission: :view, rule_type: :allow,
        context: { resource: resource, user: user, policy: policy }
      )
    end
  end
end
