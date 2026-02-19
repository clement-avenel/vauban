# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vauban::CacheKeyBuilder do
  let(:user) { double("User", id: 1) }
  let(:resource) { double("Resource", id: 1, class: double(name: "Document")) }

  before do
    described_class.clear_key_cache!
  end

  describe ".key_for_permission" do
    it "generates cache key for permission check" do
      key = described_class.key_for_permission(user, :view, resource)
      expect(key).to include("vauban:permission")
      expect(key).to include("user:1")
      expect(key).to include("view")
      expect(key).to include("Document:1")
    end

    it "memoizes keys for simple cases" do
      key1 = described_class.key_for_permission(user, :view, resource)
      key2 = described_class.key_for_permission(user, :view, resource)
      expect(key1).to eq(key2)
    end

    it "generates different keys for different actions" do
      key1 = described_class.key_for_permission(user, :view, resource)
      key2 = described_class.key_for_permission(user, :edit, resource)
      expect(key1).not_to eq(key2)
    end

    it "generates different keys for different users" do
      user2 = double("User", id: 2)
      key1 = described_class.key_for_permission(user, :view, resource)
      key2 = described_class.key_for_permission(user2, :view, resource)
      expect(key1).not_to eq(key2)
    end

    it "includes context in key when provided" do
      key_without_context = described_class.key_for_permission(user, :view, resource)
      key_with_context = described_class.key_for_permission(user, :view, resource, context: { project: 1 })
      expect(key_without_context).not_to eq(key_with_context)
    end

    it "handles complex context with MD5 hash" do
      complex_context = { project: 1, team: "engineering", role: "admin", extra: "data" }
      key = described_class.key_for_permission(user, :view, resource, context: complex_context)
      expect(key).to include("vauban:permission")
      expect(key).to match(/[a-f0-9]{32}/) # MD5 hash
    end

    it "handles simple context without hashing" do
      simple_context = { project: 1 }
      key = described_class.key_for_permission(user, :view, resource, context: simple_context)
      expect(key).to include("ctx:project=1")
    end

    it "handles resources without id" do
      resource_no_id = double("Resource", class: double(name: "Document"))
      key = described_class.key_for_permission(user, :view, resource_no_id)
      expect(key).to include("vauban:permission")
    end

    it "handles nil user" do
      key = described_class.key_for_permission(nil, :view, resource)
      expect(key).to include("user:nil")
    end
  end

  describe ".key_for_all_permissions" do
    it "generates cache key for all permissions" do
      key = described_class.key_for_all_permissions(user, resource)
      expect(key).to include("vauban:all_permissions")
      expect(key).to include("user:1")
      expect(key).to include("Document:1")
    end

    it "memoizes keys for simple cases" do
      key1 = described_class.key_for_all_permissions(user, resource)
      key2 = described_class.key_for_all_permissions(user, resource)
      expect(key1).to eq(key2)
    end

    it "includes context in key when provided" do
      key_without_context = described_class.key_for_all_permissions(user, resource)
      key_with_context = described_class.key_for_all_permissions(user, resource, context: { project: 1 })
      expect(key_without_context).not_to eq(key_with_context)
    end
  end

  describe ".key_for_policy" do
    it "generates cache key for policy lookup" do
      resource_class = Class.new do
        def self.name
          "Document"
        end
      end
      key = described_class.key_for_policy(resource_class)
      expect(key).to eq("vauban:policy:Document")
    end

    it "handles classes without name method" do
      # Create a class-like object that doesn't respond to name
      resource_class = Object.new
      # Stub respond_to? to return false for name, and use to_s instead
      allow(resource_class).to receive(:respond_to?).with(:name).and_return(false)
      allow(resource_class).to receive(:respond_to?).with(:to_s).and_return(true)
      allow(resource_class).to receive(:to_s).and_return("Document")
      key = described_class.key_for_policy(resource_class)
      expect(key).to eq("vauban:policy:Document")
    end
  end

  describe ".clear_key_cache!" do
    it "clears memoized cache keys" do
      # Generate a key to populate cache
      described_class.key_for_permission(user, :view, resource)

      # Clear cache
      described_class.clear_key_cache!

      # Generate same key again - should still work
      key = described_class.key_for_permission(user, :view, resource)
      expect(key).to be_a(String)
    end
  end
end
