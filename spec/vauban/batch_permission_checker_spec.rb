# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vauban::BatchPermissionChecker do
  let(:user) { double("User", id: 1) }
  let(:resource_class) { Class.new }
  let(:policy_class) do
    res_class = resource_class
    Class.new(Vauban::Policy) do
      resource res_class

      permission :view do
        allow_if { |r, u| r.owner == u }
      end

      permission :edit do
        allow_if { |r, u| r.owner == u }
      end
    end
  end

  let(:resource1) do
    res = double("Resource1", id: 1, owner: user, class: resource_class)
    allow(res).to receive(:class).and_return(resource_class)
    res
  end

  let(:resource2) do
    res = double("Resource2", id: 2, owner: user, class: resource_class)
    allow(res).to receive(:class).and_return(resource_class)
    res
  end

  before do
    stub_const("TestResource", resource_class)
    stub_const("TestResourcePolicy", policy_class)
    Vauban::Registry.register(TestResourcePolicy)
  end

  describe "#call" do
    it "returns empty hash for empty resources" do
      checker = described_class.new(user, [])
      expect(checker.call).to eq({})
    end

    it "returns permissions hash for each resource" do
      checker = described_class.new(user, [ resource1, resource2 ])
      result = checker.call

      expect(result).to be_a(Hash)
      expect(result.keys).to include(resource1, resource2)
      expect(result[resource1]).to be_a(Hash)
      expect(result[resource2]).to be_a(Hash)
    end

    it "calculates permissions for each resource" do
      checker = described_class.new(user, [ resource1 ])
      result = checker.call

      expect(result[resource1]).to have_key("view")
      expect(result[resource1]).to have_key("edit")
      expect(result[resource1]["view"]).to be true
      expect(result[resource1]["edit"]).to be true
    end

    it "passes context to permission checks" do
      checker = described_class.new(user, [ resource1 ], context: { project: 1 })
      result = checker.call

      expect(result[resource1]).to be_a(Hash)
    end

    it "handles resources with different classes" do
      other_resource_class = Class.new
      other_policy_class = Class.new(Vauban::Policy) do
        resource other_resource_class

        permission :view do
          allow_if { |_r, _u| true }
        end
      end

      stub_const("OtherResource", other_resource_class)
      stub_const("OtherResourcePolicy", other_policy_class)
      Vauban::Registry.register(OtherResourcePolicy)

      other_resource = double("OtherResource", id: 3, class: other_resource_class)
      allow(other_resource).to receive(:class).and_return(other_resource_class)

      checker = described_class.new(user, [ resource1, other_resource ])
      result = checker.call

      expect(result.keys).to include(resource1, other_resource)
      expect(result[resource1]).to be_a(Hash)
      expect(result[other_resource]).to be_a(Hash)
    end

    it "handles resources without policies" do
      unregistered_class = Class.new
      unregistered_resource = double("UnregisteredResource", id: 4, class: unregistered_class)
      allow(unregistered_resource).to receive(:class).and_return(unregistered_class)

      checker = described_class.new(user, [ unregistered_resource ])
      result = checker.call

      expect(result[unregistered_resource]).to eq({})
    end

    context "with caching" do
      let(:cache_store) { double("CacheStore") }

      before do
        Vauban.configure do |config|
          config.cache_store = cache_store
        end
      end

      after do
        Vauban.configuration = nil
      end

      it "uses cached results when available" do
        cache_key1 = Vauban::Cache.key_for_all_permissions(user, resource1)
        cache_key2 = Vauban::Cache.key_for_all_permissions(user, resource2)

        cached_permissions = { "view" => true, "edit" => false }

        # Mock policy cache fetch - Cache.fetch calls cache_store.fetch with a block
        allow(cache_store).to receive(:fetch) do |key, options = {}, &block|
          if key.to_s.include?("policy")
            # For policy cache, yield to execute block (which returns the policy)
            block ? block.call : policy_class
          elsif key == cache_key1
            cached_permissions
          else
            block ? block.call : nil
          end
        end
        # Mock read_multi for batch cache reads
        allow(cache_store).to receive(:respond_to?).with(:read_multi).and_return(true)
        allow(cache_store).to receive(:read_multi).with(cache_key1, cache_key2).and_return(
          cache_key1 => cached_permissions
        )

        checker = described_class.new(user, [ resource1, resource2 ])
        result = checker.call

        expect(result[resource1]).to eq(cached_permissions)
        expect(result[resource2]).to be_a(Hash) # Not cached, so calculated
      end

      it "falls back to individual checks when read_multi not supported" do
        # Mock policy cache fetch - Cache.fetch calls cache_store.fetch with a block
        allow(cache_store).to receive(:fetch) do |key, options = {}, &block|
          if key.to_s.include?("policy")
            # For policy cache, yield to execute block (which returns the policy)
            block ? block.call : policy_class
          else
            block ? block.call : nil
          end
        end
        allow(cache_store).to receive(:respond_to?).with(:read_multi).and_return(false)

        checker = described_class.new(user, [ resource1 ])
        result = checker.call

        expect(result[resource1]).to be_a(Hash)
      end
    end
  end
end
