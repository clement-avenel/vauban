# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vauban::Cache do
  let(:cache_store) { double("CacheStore") }
  let(:user) { double("User", id: 1) }
  let(:document_class) { Class.new }
  let(:resource) { double("Document", id: 1, class: document_class) }

  before do
    stub_const("Document", document_class)
    Vauban.configure do |config|
      config.cache_store = cache_store
      config.cache_ttl = 3600
    end
  end

  # --- Key building ---

  describe ".key_for_permission" do
    it "generates a cache key including all parts" do
      key = described_class.key_for_permission(user, :view, resource)
      expect(key).to include("vauban:permission", "user:1", "view", "Document:1")
    end

    it "memoizes keys for simple cases" do
      key1 = described_class.key_for_permission(user, :view, resource)
      key2 = described_class.key_for_permission(user, :view, resource)
      expect(key1).to eq(key2)
    end

    it "varies by action" do
      key1 = described_class.key_for_permission(user, :view, resource)
      key2 = described_class.key_for_permission(user, :edit, resource)
      expect(key1).not_to eq(key2)
    end

    it "varies by user" do
      key1 = described_class.key_for_permission(user, :view, resource)
      key2 = described_class.key_for_permission(double("User", id: 2), :view, resource)
      expect(key1).not_to eq(key2)
    end

    it "varies by context" do
      key1 = described_class.key_for_permission(user, :view, resource, context: { project: 1 })
      key2 = described_class.key_for_permission(user, :view, resource, context: { project: 2 })
      expect(key1).not_to eq(key2)
    end

    it "handles simple context inline" do
      key = described_class.key_for_permission(user, :view, resource, context: { project: 1 })
      expect(key).to include("ctx:project=1")
    end

    it "hashes complex context" do
      ctx = { project: 1, team: "eng", role: "admin", extra: "data" }
      key = described_class.key_for_permission(user, :view, resource, context: ctx)
      expect(key).to match(/[a-f0-9]{64}/)
    end

    it "handles resources without id" do
      no_id = double("Resource", class: double(name: "Document"))
      key = described_class.key_for_permission(user, :view, no_id)
      expect(key).to include("vauban:permission")
    end

    it "handles nil user" do
      key = described_class.key_for_permission(nil, :view, resource)
      expect(key).to include("user:nil")
    end

    it "handles class as resource" do
      key = described_class.key_for_permission(user, :view, Document)
      expect(key).to include("class:Document")
    end
  end

  describe ".key_for_all_permissions" do
    it "generates key with all_permissions prefix" do
      key = described_class.key_for_all_permissions(user, resource)
      expect(key).to include("vauban:all_permissions", "user:1", "Document:1")
    end

    it "memoizes keys for simple cases" do
      key1 = described_class.key_for_all_permissions(user, resource)
      key2 = described_class.key_for_all_permissions(user, resource)
      expect(key1).to eq(key2)
    end

    it "varies by context" do
      key1 = described_class.key_for_all_permissions(user, resource)
      key2 = described_class.key_for_all_permissions(user, resource, context: { project: 1 })
      expect(key1).not_to eq(key2)
    end
  end

  describe ".key_for_policy" do
    it "generates policy cache key" do
      expect(described_class.key_for_policy(Document)).to eq("vauban:policy:Document")
    end

    it "falls back to to_s for objects without name" do
      obj = Object.new
      allow(obj).to receive(:respond_to?).with(:name).and_return(false)
      key = described_class.key_for_policy(obj)
      expect(key).to start_with("vauban:policy:")
    end
  end

  describe ".key_for_relation_scope" do
    it "generates key from subject, relation, and object type" do
      key = described_class.key_for_relation_scope(user, :viewer, Document)
      expect(key).to eq("vauban:relation_scope:user:1:viewer:Document")
    end

    it "varies by relation" do
      key1 = described_class.key_for_relation_scope(user, :viewer, Document)
      key2 = described_class.key_for_relation_scope(user, :editor, Document)
      expect(key1).not_to eq(key2)
    end

    it "varies by object type" do
      stub_const("Project", Class.new)
      key1 = described_class.key_for_relation_scope(user, :viewer, Document)
      key2 = described_class.key_for_relation_scope(user, :viewer, Project)
      expect(key1).not_to eq(key2)
    end
  end

  describe ".user_key" do
    it "returns 'user:nil' for nil" do
      expect(described_class.user_key(nil)).to eq("user:nil")
    end

    it "returns 'user:id' for user with id" do
      expect(described_class.user_key(user)).to eq("user:1")
    end

    it "uses to_key when no id" do
      obj = double("User", to_key: [ 1, 2, 3 ])
      expect(described_class.user_key(obj)).to eq("user:1-2-3")
    end

    it "falls back to object_id" do
      obj = double("User")
      allow(obj).to receive(:object_id).and_return(99999)
      expect(described_class.user_key(obj)).to eq("user:99999")
    end
  end

  describe ".resource_key" do
    it "returns 'nil' for nil" do
      expect(described_class.resource_key(nil)).to eq("nil")
    end

    it "returns 'ClassName:id' for resource with id" do
      expect(described_class.resource_key(resource)).to eq("Document:1")
    end

    it "returns 'class:ClassName' for a Class" do
      expect(described_class.resource_key(Document)).to eq("class:Document")
    end

    it "falls back to object_id" do
      obj = double("Resource", class: double(name: "Document"))
      allow(obj).to receive(:object_id).and_return(99999)
      expect(described_class.resource_key(obj)).to eq("Document:99999")
    end
  end

  describe ".clear_key_cache!" do
    it "clears memoized keys without breaking subsequent calls" do
      described_class.key_for_permission(user, :view, resource)
      described_class.clear_key_cache!
      expect(described_class.key_for_permission(user, :view, resource)).to be_a(String)
    end
  end

  # --- Store operations ---

  describe ".fetch" do
    context "when cache is enabled" do
      it "returns cached value" do
        allow(cache_store).to receive(:fetch).with("k", expires_in: 3600).and_return("cached")
        expect(described_class.fetch("k") { "computed" }).to eq("cached")
      end

      it "yields and caches on miss" do
        allow(cache_store).to receive(:fetch).with("k", expires_in: 3600).and_yield
        expect(described_class.fetch("k") { "computed" }).to eq("computed")
      end

      it "uses custom TTL" do
        allow(cache_store).to receive(:fetch).with("k", expires_in: 1800).and_yield
        described_class.fetch("k", ttl: 1800) { "v" }
        expect(cache_store).to have_received(:fetch).with("k", expires_in: 1800)
      end

      it "falls back on cache error" do
        allow(cache_store).to receive(:fetch).and_raise(StandardError, "boom")
        allow(Rails).to receive(:logger).and_return(double("Logger", error: nil)) if defined?(Rails)
        expect(described_class.fetch("k") { "fallback" }).to eq("fallback")
      end
    end

    context "when cache is disabled" do
      before { Vauban.configure { |c| c.cache_store = nil } }

      it "yields directly" do
        expect(described_class.fetch("k") { "val" }).to eq("val")
      end
    end
  end

  describe ".delete" do
    it "deletes from store" do
      allow(cache_store).to receive(:delete)
      described_class.delete("k")
      expect(cache_store).to have_received(:delete).with("k")
    end

    it "no-ops when disabled" do
      Vauban.configure { |c| c.cache_store = nil }
      expect { described_class.delete("k") }.not_to raise_error
    end
  end

  describe ".clear" do
    it "uses delete_matched when supported" do
      allow(cache_store).to receive(:respond_to?).with(:delete_matched).and_return(true)
      allow(cache_store).to receive(:delete_matched)
      described_class.clear
      expect(cache_store).to have_received(:delete_matched).with("vauban:*")
    end

    it "does not raise when delete_matched unsupported" do
      allow(cache_store).to receive(:respond_to?).with(:delete_matched).and_return(false)
      expect { described_class.clear }.not_to raise_error
    end
  end

  describe ".clear_for_resource" do
    it "clears matching pattern" do
      allow(cache_store).to receive(:respond_to?).with(:delete_matched).and_return(true)
      allow(cache_store).to receive(:delete_matched)
      described_class.clear_for_resource(resource)
      expect(cache_store).to have_received(:delete_matched).with(match(/Document:1/))
    end
  end

  describe ".clear_for_user" do
    it "clears permission and relation-scope patterns for user" do
      allow(cache_store).to receive(:respond_to?).with(:delete_matched).and_return(true)
      allow(cache_store).to receive(:delete_matched)
      described_class.clear_for_user(user)
      expect(cache_store).to have_received(:delete_matched).with("vauban:*:user:1:*")
      expect(cache_store).to have_received(:delete_matched).with("vauban:relation_scope:user:1:*")
    end
  end

  describe ".clear_relation_scope_for_user" do
    it "clears only relation-scope entries for that user" do
      allow(cache_store).to receive(:respond_to?).with(:delete_matched).and_return(true)
      allow(cache_store).to receive(:delete_matched)
      described_class.clear_relation_scope_for_user(user)
      expect(cache_store).to have_received(:delete_matched).with("vauban:relation_scope:user:1:*")
    end
  end

  describe ".clear_relation_scope_for_object_type" do
    it "clears relation-scope entries for that object type" do
      allow(cache_store).to receive(:respond_to?).with(:delete_matched).and_return(true)
      allow(cache_store).to receive(:delete_matched)
      described_class.clear_relation_scope_for_object_type(Document)
      expect(cache_store).to have_received(:delete_matched).with("vauban:relation_scope:*:*:Document")
    end
  end
end
