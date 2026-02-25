# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vauban::Policy do
  let(:user) { double("User", id: 1) }
  let(:document) { double("Document", id: 1, owner: user, public?: false) }

  describe "policy definition" do
    let(:policy_class) do
      Class.new(Vauban::Policy) do
        resource Document

        permission :view do
          allow_if { |doc, user| doc.owner == user }
          allow_if { |doc| doc.public? }
        end
      end
    end

    before do
      stub_const("Document", Class.new)
      stub_const("TestPolicy", policy_class)
      Vauban::Registry.register(TestPolicy)
    end

    it "defines permissions" do
      expect(TestPolicy.available_permissions).to include(:view)
    end

    it "checks permissions correctly" do
      policy = TestPolicy.new(user)
      expect(policy.allowed?(:view, document)).to be true
    end
  end

  describe ".resource" do
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

    it "sets resource_class" do
      expect(TestResourcePolicy.resource_class).to eq(TestResource)
    end
  end

  describe ".permission" do
    let(:resource_class) { Class.new }
    let(:policy_class) do
      res_class = resource_class
      Class.new(Vauban::Policy) do
        resource res_class

        permission :view do
          allow_if { |r| r.public? }
        end

        permission :edit do
          allow_if { |r, u| r.owner == u }
        end
      end
    end

    before do
      stub_const("TestResource", resource_class)
      stub_const("TestResourcePolicy", policy_class)
    end

    it "defines multiple permissions" do
      expect(TestResourcePolicy.available_permissions).to include(:view, :edit)
    end

    it "stores permission objects" do
      expect(TestResourcePolicy.permissions[:view]).to be_a(Vauban::Permission)
      expect(TestResourcePolicy.permissions[:edit]).to be_a(Vauban::Permission)
    end
  end

  describe ".available_permissions" do
    let(:resource_class) { Class.new }
    let(:policy_class) do
      res_class = resource_class
      Class.new(Vauban::Policy) do
        resource res_class

        permission :view do
          allow_if { |r| r.public? }
        end

        permission :edit do
          allow_if { |r, u| r.owner == u }
        end
      end
    end

    before do
      stub_const("TestResource", resource_class)
      stub_const("TestResourcePolicy", policy_class)
    end

    it "returns array of permission names" do
      expect(TestResourcePolicy.available_permissions).to eq([ :view, :edit ])
    end

    it "returns empty array when no permissions defined" do
      res_class = resource_class
      empty_policy = Class.new(Vauban::Policy) do
        resource res_class
      end
      stub_const("EmptyPolicy", empty_policy)
      expect(EmptyPolicy.available_permissions).to eq([])
    end
  end

  describe ".relationship" do
    let(:resource_class) { Class.new }
    let(:policy_class) do
      res_class = resource_class
      Class.new(Vauban::Policy) do
        resource res_class

        relationship :owner do
          owner
        end
      end
    end

    before do
      stub_const("TestResource", resource_class)
      stub_const("TestResourcePolicy", policy_class)
    end

    it "defines relationships" do
      expect(TestResourcePolicy.relationships).to have_key(:owner)
    end

    it "stores relationship blocks" do
      expect(TestResourcePolicy.relationships[:owner]).to be_a(Proc)
    end
  end

  describe ".relation (ReBAC schema)" do
    let(:resource_class) { Class.new }
    let(:policy_class) do
      res_class = resource_class
      Class.new(Vauban::Policy) do
        resource res_class

        relation :viewer
        relation :editor, requires: [ :viewer ]
        relation :owner, requires: [ :editor, :viewer ]
      end
    end

    before do
      stub_const("TestResource", resource_class)
      stub_const("TestResourcePolicy", policy_class)
    end

    it "builds implied_by so effective_relations includes implying relations" do
      expect(policy_class.effective_relations(:viewer)).to contain_exactly(:viewer, :editor, :owner)
      expect(policy_class.effective_relations(:editor)).to contain_exactly(:editor, :owner)
      expect(policy_class.effective_relations(:owner)).to eq([ :owner ])
    end

    it "effective_relations for an undeclared relation returns only that relation" do
      expect(policy_class.effective_relations(:other)).to eq([ :other ])
    end
  end

  describe ".relation with via (indirect traversal)" do
    let(:team_class) { Class.new }
    let(:resource_class) { Class.new }
    let(:policy_class) do
      res_class = resource_class
      team_klass = team_class
      Class.new(Vauban::Policy) do
        resource res_class

        relation :viewer
        relation :viewer, via: { member: team_klass }
        relation :editor, requires: [ :viewer ]
        relation :editor, via: { member: team_klass }
      end
    end

    before do
      stub_const("Team", team_class)
      stub_const("TestResource", resource_class)
      stub_const("TestResourcePolicy", policy_class)
    end

    it "stores relation_via for indirect paths" do
      expect(policy_class.relation_via_for(:viewer)).to eq({ member: Team })
      expect(policy_class.relation_via_for(:editor)).to eq({ member: Team })
      expect(policy_class.relation_via_for(:owner)).to eq({})
    end
  end

  describe ".permission with relation:" do
    let(:resource_class) { Class.new }
    let(:policy_class) do
      res_class = resource_class
      Class.new(Vauban::Policy) do
        resource res_class

        permission :view, relation: :viewer do
          allow_if { |r| r.public? }
        end
      end
    end

    before do
      stub_const("TestResource", resource_class)
      stub_const("TestResourcePolicy", policy_class)
      Vauban::Registry.register(policy_class)
    end

    it "adds an implicit allow_if for has_relation?" do
      perm = policy_class.permissions[:view]
      expect(perm.rules.count { |r| r.type == :allow }).to be >= 1
    end
  end

  describe ".scope with relation:" do
    it "stores scope_config with relation and optional block" do
      resource_class = Class.new
      policy_class = Class.new(Vauban::Policy) do
        resource resource_class

        scope :view, relation: :viewer do |user, _ctx|
          resource_class.where(public: true)
        end
      end
      stub_const("TestResource", resource_class)
      stub_const("TestResourcePolicy", policy_class)

      config = policy_class.scope_configs[:view]
      expect(config[:relation]).to eq(:viewer)
      expect(config[:block]).to be_a(Proc)
    end
  end

  describe ".condition" do
    let(:resource_class) { Class.new }
    let(:policy_class) do
      res_class = resource_class
      Class.new(Vauban::Policy) do
        resource res_class

        condition :is_public do |resource, user, context|
          resource.public?
        end
      end
    end

    before do
      stub_const("TestResource", resource_class)
      stub_const("TestResourcePolicy", policy_class)
    end

    it "defines conditions" do
      expect(TestResourcePolicy.conditions).to have_key(:is_public)
    end

    it "stores condition blocks" do
      expect(TestResourcePolicy.conditions[:is_public]).to be_a(Proc)
    end
  end

  describe ".scope" do
    let(:resource_class) { Class.new }
    let(:policy_class) do
      res_class = resource_class
      Class.new(Vauban::Policy) do
        resource res_class

        scope :view do |user, context|
          all.select { |r| r.owner == user || r.public? }
        end
      end
    end

    before do
      stub_const("TestResource", resource_class)
      stub_const("TestResourcePolicy", policy_class)
    end

    it "defines scopes" do
      expect(TestResourcePolicy.scopes).to have_key(:view)
    end

    it "stores scope blocks" do
      expect(TestResourcePolicy.scopes[:view]).to be_a(Proc)
    end
  end

  describe "#initialize" do
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

    it "accepts user parameter" do
      policy = TestResourcePolicy.new(user)
      expect(policy.user).to eq(user)
    end
  end

  describe "#allowed?" do
    let(:resource_class) { Class.new }
    let(:policy_class) do
      res_class = resource_class
      Class.new(Vauban::Policy) do
        resource res_class

        permission :view do
          allow_if { |r| r.public? }
        end

        permission :edit do
          allow_if { |r, u| r.owner == u }
        end
      end
    end

    before do
      stub_const("TestResource", resource_class)
      stub_const("TestResourcePolicy", policy_class)
    end

    it "returns true for allowed permissions" do
      policy = TestResourcePolicy.new(user)
      public_resource = double("Resource", public?: true)
      expect(policy.allowed?(:view, public_resource)).to be true
    end

    it "returns false for denied permissions" do
      policy = TestResourcePolicy.new(user)
      private_resource = double("Resource", public?: false)
      expect(policy.allowed?(:view, private_resource)).to be false
    end

    it "returns false for undefined permissions" do
      policy = TestResourcePolicy.new(user)
      resource = double("Resource")
      expect(policy.allowed?(:delete, resource)).to be false
    end

    it "passes context to permission" do
      policy = TestResourcePolicy.new(user)
      resource = double("Resource", public?: true)
      permission = TestResourcePolicy.permissions[:view]
      allow(permission).to receive(:allowed?).and_return(true)
      policy.allowed?(:view, resource, context: { admin: true })
      expect(permission).to have_received(:allowed?).with(resource, user, context: { admin: true }, policy: policy)
    end
  end

  describe "#all_permissions" do
    let(:resource_class) { Class.new }
    let(:policy_class) do
      res_class = resource_class
      Class.new(Vauban::Policy) do
        resource res_class

        permission :view do
          allow_if { |r| r.public? }
        end

        permission :edit do
          allow_if { |r, u| r.owner == u }
        end
      end
    end

    before do
      stub_const("TestResource", resource_class)
      stub_const("TestResourcePolicy", policy_class)
    end

    it "returns hash of all permissions" do
      policy = TestResourcePolicy.new(user)
      public_resource = double("Resource", public?: true, owner: user)
      permissions = policy.all_permissions(public_resource)
      expect(permissions).to be_a(Hash)
      expect(permissions.keys).to include("view", "edit")
    end

    it "includes permission results" do
      policy = TestResourcePolicy.new(user)
      public_resource = double("Resource", public?: true, owner: user)
      permissions = policy.all_permissions(public_resource)
      expect(permissions["view"]).to be true
      expect(permissions["edit"]).to be true
    end

    it "passes context to each permission check" do
      policy = TestResourcePolicy.new(user)
      resource = double("Resource", public?: false, owner: user)
      permissions = policy.all_permissions(resource, context: { admin: true })
      expect(permissions).to be_a(Hash)
    end
  end

  describe "#scope" do
    let(:resource_class) { Class.new }
    let(:policy_class) do
      res_class = resource_class
      Class.new(Vauban::Policy) do
        resource res_class

        scope :view do |user, context|
          all.select { |r| r.owner == user || r.public? }
        end
      end
    end

    before do
      stub_const("TestResource", resource_class)
      stub_const("TestResourcePolicy", policy_class)
    end

    it "returns scoped records when scope defined" do
      policy = TestResourcePolicy.new(user)
      all_resources = [
        double("R1", owner: user, public?: false),
        double("R2", owner: double("Other"), public?: true)
      ]
      allow(resource_class).to receive(:all).and_return(all_resources)

      result = policy.scope(:view)
      expect(result.length).to eq(2)
    end

    it "returns all records when no scope defined" do
      policy = TestResourcePolicy.new(user)
      all_resources = [ double("R1"), double("R2") ]
      allow(resource_class).to receive(:all).and_return(all_resources)

      result = policy.scope(:nonexistent)
      expect(result).to eq(all_resources)
    end

    it "passes context to scope block" do
      policy = TestResourcePolicy.new(user)
      all_resources = [
        double("R1", owner: user, public?: false),
        double("R2", owner: double("Other"), public?: true)
      ]
      allow(resource_class).to receive(:all).and_return(all_resources)

      result = policy.scope(:view, context: { admin: true })
      expect(result).to be_an(Array)
      # Verify scope was executed (should return filtered results)
      expect(result.length).to eq(2)
    end

    it "raises ArgumentError if resource_class doesn't support scoping" do
      non_ar_resource = Class.new
      res_class = non_ar_resource
      non_ar_policy = Class.new(Vauban::Policy) do
        resource res_class

        scope :view do |user, context|
          []
        end
      end
      stub_const("NonARResource", non_ar_resource)
      stub_const("NonARPolicy", non_ar_policy)

      policy = NonARPolicy.new(user)
      expect {
        policy.scope(:view)
      }.to raise_error(ArgumentError) do |error|
        expect(error.message).to include("must respond to .all")
        expect(error.message).to include("NonARResource")
      end
    end
  end

  describe "#resource_class" do
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

    it "returns the resource class" do
      policy = TestResourcePolicy.new(user)
      expect(policy.resource_class).to eq(TestResource)
    end
  end

  describe "#evaluate_relationship" do
    let(:resource_class) { Class.new }
    let(:policy_class) do
      res_class = resource_class
      Class.new(Vauban::Policy) do
        resource res_class

        relationship :owner do
          owner
        end
      end
    end

    before do
      stub_const("TestResource", resource_class)
      stub_const("TestResourcePolicy", policy_class)
    end

    it "evaluates relationship block in resource context" do
      policy = TestResourcePolicy.new(user)
      resource = double("Resource", owner: user)
      result = policy.evaluate_relationship(:owner, resource)
      expect(result).to eq(user)
    end

    it "returns nil for undefined relationships" do
      policy = TestResourcePolicy.new(user)
      resource = double("Resource")
      result = policy.evaluate_relationship(:nonexistent, resource)
      expect(result).to be_nil
    end
  end

  describe "#evaluate_condition" do
    let(:resource_class) { Class.new }
    let(:policy_class) do
      res_class = resource_class
      Class.new(Vauban::Policy) do
        resource res_class

        condition :is_public do |resource, user, context|
          resource.public?
        end
      end
    end

    before do
      stub_const("TestResource", resource_class)
      stub_const("TestResourcePolicy", policy_class)
    end

    it "evaluates condition block" do
      policy = TestResourcePolicy.new(user)
      public_resource = double("Resource", public?: true)
      result = policy.evaluate_condition(:is_public, public_resource, {})
      expect(result).to be true
    end

    it "passes resource, user, and context to condition" do
      policy = TestResourcePolicy.new(user)
      resource = double("Resource", public?: false)
      context = { admin: true }
      result = policy.evaluate_condition(:is_public, resource, context)
      expect(result).to be false
    end

    it "returns nil for undefined conditions" do
      policy = TestResourcePolicy.new(user)
      resource = double("Resource")
      result = policy.evaluate_condition(:nonexistent, resource, {})
      expect(result).to be_nil
    end
  end
end
