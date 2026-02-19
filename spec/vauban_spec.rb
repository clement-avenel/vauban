# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vauban do
  let(:user) { double("User", id: 1) }
  let(:resource_class) { Class.new }
  let(:policy_class) do
    res_class = resource_class
    Class.new(Vauban::Policy) do
      resource res_class

      permission :view do
        allow_if { |r, u| r.owner == u }
        allow_if { |r| r.public? }
      end

      permission :edit do
        allow_if { |r, u| r.owner == u }
      end

      permission :delete do
        allow_if { |r, u| r.owner == u && !r.archived? }
      end
    end
  end

  before do
    stub_const("TestResource", resource_class)
    stub_const("TestResourcePolicy", policy_class)
    Vauban::Registry.register(TestResourcePolicy)
  end

  it "has a version number" do
    expect(Vauban::VERSION).not_to be nil
  end

  describe ".configure" do
    it "allows configuration" do
      Vauban.configure do |config|
        config.current_user_method = :current_user
      end

      expect(Vauban.config.current_user_method).to eq(:current_user)
    end

    it "initializes configuration if not set" do
      Vauban.configuration = nil
      config = Vauban.configure
      expect(config).to be_a(Vauban::Configuration)
    end

    it "yields configuration block" do
      yielded_config = nil
      Vauban.configure do |config|
        yielded_config = config
      end
      expect(yielded_config).to eq(Vauban.configuration)
    end
  end

  describe ".config" do
    it "returns configuration instance" do
      expect(Vauban.config).to be_a(Vauban::Configuration)
    end

    it "initializes configuration if not set" do
      Vauban.configuration = nil
      expect(Vauban.config).to be_a(Vauban::Configuration)
    end
  end

  describe ".authorize" do
    let(:resource) do
      res = double("Resource", id: 1, owner: user, public?: false)
      allow(res).to receive(:class).and_return(TestResource)
      res
    end

    it "allows authorized actions" do
      expect(Vauban.authorize(user, :view, resource)).to be true
    end

    it "raises Unauthorized for unauthorized actions" do
      other_user = double("User", id: 2)
      expect {
        Vauban.authorize(other_user, :edit, resource)
      }.to raise_error(Vauban::Unauthorized)
    end

    it "raises PolicyNotFound when no policy exists" do
      unregistered_resource_class = Class.new do
        def self.name
          "UnregisteredResource"
        end
      end
      unregistered_resource = double("Resource", id: 1, class: unregistered_resource_class)

      # Ensure Registry returns nil for this resource class
      allow(Vauban::Registry).to receive(:policy_for).with(unregistered_resource_class).and_return(nil)

      expect {
        Vauban.authorize(user, :view, unregistered_resource)
      }.to raise_error(Vauban::PolicyNotFound) do |error|
        expect(error.message).to include("UnregisteredResource")
        expect(error.message).to include("UnregisteredResourcePolicy")
        expect(error.message).to include("app/policies/unregistered_resource_policy.rb")
        expect(error.resource_class).to eq(unregistered_resource_class)
        expect(error.expected_policy_name).to eq("UnregisteredResourcePolicy")
      end
    end

    it "passes context to policy" do
      policy_instance = TestResourcePolicy.new(user)
      allow(TestResourcePolicy).to receive(:new).and_return(policy_instance)
      allow(policy_instance).to receive(:allowed?).and_return(true)
      Vauban.authorize(user, :view, resource, context: { admin: true })
      expect(policy_instance).to have_received(:allowed?).with(:view, resource, user, context: { admin: true })
    end

    it "includes resource info in error message" do
      other_user = double("User", id: 2)
      expect {
        Vauban.authorize(other_user, :edit, resource)
      }.to raise_error(Vauban::Unauthorized) do |error|
        expect(error.message).to include("edit")
        expect(error.message).to include("TestResource")
        expect(error.user).to eq(other_user)
        expect(error.action).to eq(:edit)
        expect(error.resource).to eq(resource)
      end
    end
  end

  describe ".can?" do
    let(:resource) do
      res = double("Resource", id: 1, owner: user, public?: false)
      allow(res).to receive(:class).and_return(TestResource)
      res
    end

    it "returns true for allowed permissions" do
      expect(Vauban.can?(user, :view, resource)).to be true
    end

    it "returns false for denied permissions" do
      other_user = double("User", id: 2)
      expect(Vauban.can?(other_user, :edit, resource)).to be false
    end

    it "returns false when no policy exists" do
      unregistered_resource = double("Resource", class: Class.new)
      expect(Vauban.can?(user, :view, unregistered_resource)).to be false
    end

    it "returns false on errors" do
      allow(Vauban::Registry).to receive(:policy_for).and_raise(StandardError)
      expect(Vauban.can?(user, :view, resource)).to be false
    end

    it "passes context to policy" do
      public_resource = double("Resource", id: 1, owner: double("OtherUser"), public?: true)
      allow(public_resource).to receive(:class).and_return(TestResource)
      expect(Vauban.can?(user, :view, public_resource, context: { admin: true })).to be true
    end
  end

  describe ".all_permissions" do
    let(:resource) do
      res = double("Resource", id: 1, owner: user, public?: false, archived?: false)
      allow(res).to receive(:class).and_return(TestResource)
      res
    end

    it "returns hash of all permissions" do
      permissions = Vauban.all_permissions(user, resource)
      expect(permissions).to be_a(Hash)
      expect(permissions.keys).to include("view", "edit", "delete")
    end

    it "returns true for allowed permissions" do
      permissions = Vauban.all_permissions(user, resource)
      expect(permissions["view"]).to be true
      expect(permissions["edit"]).to be true
    end

    it "returns false for denied permissions" do
      other_user = double("User", id: 2)
      permissions = Vauban.all_permissions(other_user, resource)
      expect(permissions["edit"]).to be false
    end

    it "returns empty hash when no policy exists" do
      unregistered_resource = double("Resource", class: Class.new)
      expect(Vauban.all_permissions(user, unregistered_resource)).to eq({})
    end

    it "passes context to policy" do
      permissions = Vauban.all_permissions(user, resource, context: { admin: true })
      expect(permissions).to be_a(Hash)
    end
  end

  describe ".batch_permissions" do
    let(:resource1) do
      res = double("Resource1", id: 1, owner: user, public?: false, archived?: false)
      allow(res).to receive(:class).and_return(TestResource)
      res
    end
    let(:resource2) do
      res = double("Resource2", id: 2, owner: user, public?: false, archived?: false)
      allow(res).to receive(:class).and_return(TestResource)
      res
    end
    let(:resources) { [ resource1, resource2 ] }

    it "returns hash with resource as key" do
      result = Vauban.batch_permissions(user, resources)
      expect(result).to be_a(Hash)
      expect(result.keys).to include(resource1, resource2)
    end

    it "returns permissions hash for each resource" do
      result = Vauban.batch_permissions(user, resources)
      expect(result[resource1]).to be_a(Hash)
      expect(result[resource2]).to be_a(Hash)
    end

    it "calculates permissions for each resource" do
      result = Vauban.batch_permissions(user, resources)
      expect(result[resource1]["view"]).to be true
      expect(result[resource2]["view"]).to be true
    end

    it "handles empty resources array" do
      expect(Vauban.batch_permissions(user, [])).to eq({})
    end

    it "passes context to each permission check" do
      result = Vauban.batch_permissions(user, resources, context: { admin: true })
      expect(result[resource1]).to be_a(Hash)
    end
  end

  describe ".accessible_by" do
    let(:resource_class) { Class.new }
    let(:policy_with_scope) do
      res_class = resource_class
      Class.new(Vauban::Policy) do
        resource res_class

        scope :view do |user, context|
          all.select { |r| r.owner == user || r.public? }
        end
      end
    end

    before do
      stub_const("ScopedResource", resource_class)
      stub_const("ScopedResourcePolicy", policy_with_scope)
      Vauban::Registry.register(ScopedResourcePolicy)
    end

    it "returns scoped records" do
      allow(resource_class).to receive(:all).and_return([
        double("R1", owner: user, public?: false),
        double("R2", owner: double("Other"), public?: true)
      ])

      result = Vauban.accessible_by(user, :view, resource_class)
      expect(result.length).to eq(2)
    end

    it "raises PolicyNotFound when no policy exists" do
      unregistered_class = Class.new do
        def self.name
          "UnregisteredScopedResource"
        end
      end
      expect {
        Vauban.accessible_by(user, :view, unregistered_class)
      }.to raise_error(Vauban::PolicyNotFound) do |error|
        expect(error.message).to include("UnregisteredScopedResource")
        expect(error.message).to include("UnregisteredScopedResourcePolicy")
        expect(error.resource_class).to eq(unregistered_class)
      end
    end

    it "returns all records when no scope defined" do
      allow(resource_class).to receive(:all).and_return([ double("R1"), double("R2") ])
      result = Vauban.accessible_by(user, :nonexistent, resource_class)
      expect(result).to eq(resource_class.all)
    end

    it "passes context to scope" do
      all_resources = [
        double("R1", owner: user, public?: false),
        double("R2", owner: double("Other"), public?: true)
      ]
      allow(resource_class).to receive(:all).and_return(all_resources)
      result = Vauban.accessible_by(user, :view, resource_class, context: { admin: true })
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
    end
  end

  describe "error classes" do
    it "defines Error base class" do
      expect(Vauban::Error).to be < StandardError
    end

    it "defines Unauthorized error" do
      expect(Vauban::Unauthorized).to be < Vauban::Error
    end

    it "defines PolicyNotFound error" do
      expect(Vauban::PolicyNotFound).to be < Vauban::Error
    end

    it "defines ResourceNotFound error" do
      expect(Vauban::ResourceNotFound).to be < Vauban::Error
    end
  end
end
