# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Vauban caching integration" do
  let(:cache_store) { double("CacheStore") }
  let(:user) { double("User", id: 1) }
  let(:resource_class) { Class.new }
  let(:resource) { double("Resource", id: 1, class: resource_class) }
  let(:policy_class) do
    res_class = resource_class
    Class.new(Vauban::Policy) do
      resource res_class

      permission :view do
        allow_if { |r, u| r.id == 1 && u.id == 1 }
      end
    end
  end

  before do
    stub_const("TestResource", resource_class)
    stub_const("TestResourcePolicy", policy_class)
    Vauban::Registry.register(TestResourcePolicy)

    Vauban.configure do |config|
      config.cache_store = cache_store
      config.cache_ttl = 1.hour
    end
  end

  after do
    Vauban.configuration = nil
    Vauban::Registry.initialize_registry
  end

  describe "Vauban.can?" do
    it "caches permission check results" do
      permission_cache_key = Vauban::Cache.key_for_permission(user, :view, resource, context: {})
      policy_cache_key = Vauban::Cache.key_for_policy(resource_class)

      # Stub both policy lookup cache and permission cache
      allow(cache_store).to receive(:fetch).with(policy_cache_key, expires_in: 1.hour).and_yield
      allow(cache_store).to receive(:fetch).with(permission_cache_key, expires_in: 1.hour).and_yield
      result1 = Vauban.can?(user, :view, resource)
      expect(result1).to be true

      # Second call - policy is cached, permission should be cached
      allow(cache_store).to receive(:fetch).with(policy_cache_key, expires_in: 1.hour).and_return(TestResourcePolicy)
      allow(cache_store).to receive(:fetch).with(permission_cache_key, expires_in: 1.hour).and_return(true)
      result2 = Vauban.can?(user, :view, resource)
      expect(result2).to be true

      # Verify permission cache was called
      expect(cache_store).to have_received(:fetch).with(permission_cache_key, expires_in: 1.hour).at_least(:once)
    end

    it "uses different cache keys for different contexts" do
      cache_key1 = Vauban::Cache.key_for_permission(user, :view, resource, context: { project: 1 })
      cache_key2 = Vauban::Cache.key_for_permission(user, :view, resource, context: { project: 2 })

      expect(cache_key1).not_to eq(cache_key2)

      allow(cache_store).to receive(:fetch).and_yield
      Vauban.can?(user, :view, resource, context: { project: 1 })
      Vauban.can?(user, :view, resource, context: { project: 2 })

      expect(cache_store).to have_received(:fetch).with(cache_key1, expires_in: 1.hour)
      expect(cache_store).to have_received(:fetch).with(cache_key2, expires_in: 1.hour)
    end
  end

  describe "Vauban.all_permissions" do
    it "caches all permissions results" do
      all_perms_cache_key = Vauban::Cache.key_for_all_permissions(user, resource, context: {})
      policy_cache_key = Vauban::Cache.key_for_policy(resource_class)

      # Stub both policy lookup cache and all_permissions cache
      allow(cache_store).to receive(:fetch).with(policy_cache_key, expires_in: 1.hour).and_yield
      allow(cache_store).to receive(:fetch).with(all_perms_cache_key, expires_in: 1.hour).and_yield
      result = Vauban.all_permissions(user, resource)
      expect(result).to be_a(Hash)
      expect(result).to have_key("view")

      expect(cache_store).to have_received(:fetch).with(all_perms_cache_key, expires_in: 1.hour)
    end
  end

  describe "Vauban.batch_permissions" do
    let(:resource2) { double("Resource2", id: 2, class: resource_class) }

    it "uses cache for each resource in batch" do
      cache_key1 = Vauban::Cache.key_for_all_permissions(user, resource, context: {})
      cache_key2 = Vauban::Cache.key_for_all_permissions(user, resource2, context: {})

      allow(cache_store).to receive(:fetch).and_yield
      Vauban.batch_permissions(user, [resource, resource2], context: {})

      expect(cache_store).to have_received(:fetch).with(cache_key1, expires_in: 1.hour)
      expect(cache_store).to have_received(:fetch).with(cache_key2, expires_in: 1.hour)
    end
  end

  describe "Registry.policy_for" do
    it "caches policy lookups" do
      cache_key = Vauban::Cache.key_for_policy(resource_class)

      allow(cache_store).to receive(:fetch).with(cache_key, expires_in: 1.hour).and_yield
      policy1 = Vauban::Registry.policy_for(resource_class)
      expect(policy1).to eq(TestResourcePolicy)

      # Second call should use cached value
      allow(cache_store).to receive(:fetch).with(cache_key, expires_in: 1.hour).and_return(TestResourcePolicy)
      policy2 = Vauban::Registry.policy_for(resource_class)
      expect(policy2).to eq(TestResourcePolicy)

      expect(cache_store).to have_received(:fetch).with(cache_key, expires_in: 1.hour).twice
    end
  end

  describe "cache clearing" do
    it "clears cache for a resource" do
      allow(cache_store).to receive(:respond_to?).with(:delete_matched).and_return(true)
      allow(cache_store).to receive(:delete_matched)

      Vauban.clear_cache_for_resource!(resource)
      expect(cache_store).to have_received(:delete_matched).with(match(/vauban:\*:\*:.*:1:/))
    end

    it "clears cache for a user" do
      allow(cache_store).to receive(:respond_to?).with(:delete_matched).and_return(true)
      allow(cache_store).to receive(:delete_matched)

      Vauban.clear_cache_for_user!(user)
      expect(cache_store).to have_received(:delete_matched).with(match(/vauban:\*:user:1:/))
    end

    it "clears all cache" do
      allow(cache_store).to receive(:respond_to?).with(:delete_matched).and_return(true)
      allow(cache_store).to receive(:delete_matched)

      Vauban.clear_cache!
      expect(cache_store).to have_received(:delete_matched).with("vauban:*")
    end
  end

  describe "when cache is disabled" do
    before do
      Vauban.configure do |config|
        config.cache_store = nil
      end
    end

    it "still works without caching" do
      result = Vauban.can?(user, :view, resource)
      expect(result).to be true
      # When cache is disabled, cache_store is nil, so no calls are made
    end
  end
end
