# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vauban::Cache do
  let(:cache_store) { double("CacheStore") }
  let(:user) { double("User", id: 1) }
  let(:resource) { double("Document", id: 1, class: Document) }
  let(:document_class) { Class.new }

  before do
    stub_const("Document", document_class)
    Vauban.configure do |config|
      config.cache_store = cache_store
      config.cache_ttl = 1.hour
    end
  end

  after do
    Vauban.configuration = nil
  end

  describe ".key_for_permission" do
    it "generates a cache key for permission check" do
      key = Vauban::Cache.key_for_permission(user, :view, resource, context: {})
      expect(key).to include("vauban:permission")
      expect(key).to include("user:1")
      expect(key).to include("view")
      expect(key).to include("Document:1")
    end

    it "includes context in cache key" do
      key1 = Vauban::Cache.key_for_permission(user, :view, resource, context: { project: 1 })
      key2 = Vauban::Cache.key_for_permission(user, :view, resource, context: { project: 2 })
      expect(key1).not_to eq(key2)
    end

    it "handles nil user" do
      key = Vauban::Cache.key_for_permission(nil, :view, resource, context: {})
      expect(key).to include("user:nil")
    end

    it "handles class as resource" do
      key = Vauban::Cache.key_for_permission(user, :view, Document, context: {})
      expect(key).to include("class:Document")
    end
  end

  describe ".key_for_all_permissions" do
    it "generates a cache key for all permissions" do
      key = Vauban::Cache.key_for_all_permissions(user, resource, context: {})
      expect(key).to include("vauban:all_permissions")
      expect(key).to include("user:1")
      expect(key).to include("Document:1")
    end
  end

  describe ".key_for_policy" do
    it "generates a cache key for policy lookup" do
      key = Vauban::Cache.key_for_policy(Document)
      expect(key).to eq("vauban:policy:Document")
    end
  end

  describe ".fetch" do
    context "when cache is enabled" do
      it "returns cached value if present" do
        allow(cache_store).to receive(:fetch).with(
          "test_key",
          expires_in: 1.hour
        ).and_return("cached_value")

        result = Vauban::Cache.fetch("test_key") { "computed_value" }
        expect(result).to eq("cached_value")
      end

      it "executes block and caches result if not cached" do
        allow(cache_store).to receive(:fetch).with(
          "test_key",
          expires_in: 1.hour
        ).and_yield

        result = Vauban::Cache.fetch("test_key") { "computed_value" }
        expect(result).to eq("computed_value")
      end

      it "uses custom TTL when provided" do
        allow(cache_store).to receive(:fetch).with(
          "test_key",
          expires_in: 30.minutes
        ).and_yield

        Vauban::Cache.fetch("test_key", ttl: 30.minutes) { "value" }
        expect(cache_store).to have_received(:fetch).with("test_key", expires_in: 30.minutes)
      end

      it "handles cache errors gracefully" do
        allow(cache_store).to receive(:fetch).and_raise(StandardError, "Cache error")
        allow(Rails).to receive(:logger).and_return(double("Logger", error: nil)) if defined?(Rails)

        result = Vauban::Cache.fetch("test_key") { "fallback_value" }
        expect(result).to eq("fallback_value")
      end
    end

    context "when cache is disabled" do
      before do
        Vauban.configure do |config|
          config.cache_store = nil
        end
      end

      it "executes block without caching" do
        result = Vauban::Cache.fetch("test_key") { "computed_value" }
        expect(result).to eq("computed_value")
        # When cache is disabled, cache_store is nil, so no calls are made
      end
    end
  end

  describe ".delete" do
    it "deletes cache entry when cache is enabled" do
      allow(cache_store).to receive(:delete)
      Vauban::Cache.delete("test_key")
      expect(cache_store).to have_received(:delete).with("test_key")
    end

    it "does nothing when cache is disabled" do
      Vauban.configure do |config|
        config.cache_store = nil
      end
      # Should not raise error when cache is disabled
      expect { Vauban::Cache.delete("test_key") }.not_to raise_error
    end
  end

  describe ".clear" do
    it "clears all Vauban cache entries when cache supports delete_matched" do
      allow(cache_store).to receive(:respond_to?).with(:delete_matched).and_return(true)
      allow(cache_store).to receive(:delete_matched).with("vauban:*")

      Vauban::Cache.clear
      expect(cache_store).to have_received(:delete_matched).with("vauban:*")
    end

    it "does nothing when cache doesn't support delete_matched" do
      # Stub respond_to? to return false for delete_matched
      allow(cache_store).to receive(:respond_to?).with(:delete_matched).and_return(false)

      # Should not raise error even when cache doesn't support delete_matched
      # The implementation may log a warning if Rails.logger is available,
      # but the important behavior is that it doesn't crash
      expect { Vauban::Cache.clear }.not_to raise_error
    end
  end

  describe ".clear_for_resource" do
    it "clears cache entries for a specific resource" do
      allow(cache_store).to receive(:respond_to?).with(:delete_matched).and_return(true)
      allow(cache_store).to receive(:delete_matched)

      Vauban::Cache.clear_for_resource(resource)
      expect(cache_store).to have_received(:delete_matched).with(match(/vauban:\*:\*:Document:1:/))
    end
  end

  describe ".clear_for_user" do
    it "clears cache entries for a specific user" do
      allow(cache_store).to receive(:respond_to?).with(:delete_matched).and_return(true)
      allow(cache_store).to receive(:delete_matched)

      Vauban::Cache.clear_for_user(user)
      expect(cache_store).to have_received(:delete_matched).with(match(/vauban:\*:user:1:/))
    end
  end
end
