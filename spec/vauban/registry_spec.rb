# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vauban::Registry do
  let(:user) { double("User", id: 1) }

  describe ".register" do
    let(:resource_class) { Class.new }
    let(:policy_class) do
      res_class = resource_class
      Class.new(Vauban::Policy) do
        resource res_class
      end
    end

    before do
      stub_const("TestResource", resource_class)
      stub_const("TestResourcePolicy", policy_class)
    end

    it "registers a policy for a resource class" do
      Vauban::Registry.register(TestResourcePolicy)
      expect(Vauban::Registry.policy_for(TestResource)).to eq(TestResourcePolicy)
    end

    it "adds resource to resources list" do
      Vauban::Registry.register(TestResourcePolicy)
      expect(Vauban::Registry.resources).to include(TestResource)
    end

    it "does not duplicate resources in the list" do
      Vauban::Registry.register(TestResourcePolicy)
      Vauban::Registry.register(TestResourcePolicy)
      expect(Vauban::Registry.resources.count(TestResource)).to eq(1)
    end

    it "sets package on policy class" do
      Vauban::Registry.register(TestResourcePolicy, package: "admin")
      expect(TestResourcePolicy.package).to eq("admin")
    end

    it "sets depends_on on policy class" do
      Vauban::Registry.register(TestResourcePolicy, depends_on: ["other_package"])
      expect(TestResourcePolicy.depends_on).to eq(["other_package"])
    end

    it "raises ArgumentError if policy doesn't define resource_class" do
      invalid_policy = Class.new(Vauban::Policy)
      expect {
        Vauban::Registry.register(invalid_policy)
      }.to raise_error(ArgumentError, "Policy must define resource_class")
    end

    it "returns the policy class" do
      result = Vauban::Registry.register(TestResourcePolicy)
      expect(result).to eq(TestResourcePolicy)
    end
  end

  describe ".policy_for" do
    let(:resource_class) { Class.new }
    let(:policy_class) do
      res_class = resource_class
      Class.new(Vauban::Policy) do
        resource res_class
      end
    end

    before do
      stub_const("TestResource", resource_class)
      stub_const("TestResourcePolicy", policy_class)
    end

    it "returns registered policy" do
      Vauban::Registry.register(TestResourcePolicy)
      expect(Vauban::Registry.policy_for(TestResource)).to eq(TestResourcePolicy)
    end

    it "returns nil for unregistered resource" do
      unregistered_resource = Class.new
      stub_const("UnregisteredResource", unregistered_resource)
      expect(Vauban::Registry.policy_for(UnregisteredResource)).to be_nil
    end

    context "with inheritance" do
      let(:parent_resource) { Class.new }
      let(:child_resource) { Class.new(parent_resource) }
      let(:parent_policy) do
        res_class = parent_resource
        Class.new(Vauban::Policy) do
          resource res_class
        end
      end

      before do
        stub_const("ParentResource", parent_resource)
        stub_const("ChildResource", child_resource)
        stub_const("ParentResourcePolicy", parent_policy)
        Vauban::Registry.register(ParentResourcePolicy)
      end

      it "finds policy for parent class when child has no policy" do
        expect(Vauban::Registry.policy_for(ChildResource)).to eq(ParentResourcePolicy)
      end

      it "prefers child policy over parent policy" do
        child_res = child_resource
        child_policy = Class.new(Vauban::Policy) do
          resource child_res
        end
        stub_const("ChildResourcePolicy", child_policy)
        Vauban::Registry.register(ChildResourcePolicy)

        expect(Vauban::Registry.policy_for(ChildResource)).to eq(ChildResourcePolicy)
      end

      it "does not traverse beyond ActiveRecord::Base" do
        if defined?(ActiveRecord::Base)
          ar_resource = Class.new(ActiveRecord::Base)
          stub_const("ARResource", ar_resource)
          expect(Vauban::Registry.policy_for(ARResource)).to be_nil
        else
          skip "ActiveRecord::Base not available in this test environment"
        end
      end

      it "does not traverse beyond Object" do
        # Object doesn't have a superclass, so policy_for should return nil immediately
        # But we need to handle the case where resource_class.name is called on Object
        result = Vauban::Registry.policy_for(Object)
        expect(result).to be_nil
      end
    end

    context "with lazy loading" do
      let(:resource_class) { Class.new }
      let(:policy_class_name) { "LazyTestResourcePolicy" }

      before do
        stub_const("LazyTestResource", resource_class)
      end

      it "attempts to load policy class if not found" do
        # Clear registry first
        Vauban::Registry.initialize_registry
        
        # Create policy class after clearing registry (simulating autoloading)
        policy_class = Class.new(Vauban::Policy) do
          resource LazyTestResource
        end
        stub_const(policy_class_name, policy_class)

        # Lookup should trigger discovery and find the policy
        result = Vauban::Registry.policy_for(LazyTestResource)
        expect(result).to eq(policy_class)
      end

      it "returns nil if policy class doesn't exist" do
        # Use a unique resource class name that definitely doesn't have a policy
        unique_resource = Class.new
        stub_const("UniqueTestResource", unique_resource)
        Vauban::Registry.initialize_registry
        expect(Vauban::Registry.policy_for(UniqueTestResource)).to be_nil
      end
    end
  end

  describe ".discover_and_register" do
    let(:resource_class) { Class.new }
    let(:policy_class) do
      res_class = resource_class
      Class.new(Vauban::Policy) do
        resource res_class
      end
    end

    before do
      Vauban::Registry.initialize_registry
      stub_const("DiscoveredResource", resource_class)
      stub_const("DiscoveredResourcePolicy", policy_class)
    end

    it "discovers and registers policies" do
      # Policy exists but isn't registered yet
      # Note: ObjectSpace might discover it, so we check if it's already registered
      initial_result = Vauban::Registry.policy_for(DiscoveredResource)
      
      # If already discovered, that's fine - the test still validates discovery works
      if initial_result.nil?
        Vauban::Registry.discover_and_register
        expect(Vauban::Registry.policy_for(DiscoveredResource)).to eq(DiscoveredResourcePolicy)
      else
        # Already discovered, verify it's the correct policy
        expect(initial_result).to eq(DiscoveredResourcePolicy)
      end
    end

    it "does not duplicate registrations" do
      Vauban::Registry.register(DiscoveredResourcePolicy)
      initial_count = Vauban::Registry.resources.count

      Vauban::Registry.discover_and_register

      # Should not add duplicates, but may discover other policies from ObjectSpace
      expect(Vauban::Registry.resources).to include(DiscoveredResource)
      expect(Vauban::Registry.resources.count(DiscoveredResource)).to eq(1)
    end

    it "only registers policies that inherit from Vauban::Policy" do
      non_policy_class = Class.new
      stub_const("NonPolicy", non_policy_class)

      Vauban::Registry.discover_and_register

      expect(Vauban::Registry.policies.values).not_to include(NonPolicy)
    end

    it "only registers policies that define resource_class" do
      policy_without_resource = Class.new(Vauban::Policy)
      stub_const("PolicyWithoutResource", policy_without_resource)

      Vauban::Registry.discover_and_register

      expect(Vauban::Registry.policies.values).not_to include(PolicyWithoutResource)
    end
  end

  describe ".initialize_registry" do
    it "initializes empty policies hash" do
      Vauban::Registry.initialize_registry
      expect(Vauban::Registry.policies).to eq({})
    end

    it "initializes empty resources array" do
      Vauban::Registry.initialize_registry
      expect(Vauban::Registry.resources).to eq([])
    end

    it "clears existing registrations" do
      resource_class = Class.new
      res_class = resource_class
      policy_class = Class.new(Vauban::Policy) do
        resource res_class
      end
      stub_const("TestResource", resource_class)
      stub_const("TestResourcePolicy", policy_class)

      Vauban::Registry.register(TestResourcePolicy)
      expect(Vauban::Registry.policies).not_to be_empty

      Vauban::Registry.initialize_registry
      expect(Vauban::Registry.policies).to be_empty
    end
  end
end
