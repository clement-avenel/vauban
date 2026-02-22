# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vauban::Permission do
  let(:user) { double("User", id: 1, name: "Test User") }
  let(:resource) { double("Resource", id: 1, owner: user, public?: false) }
  let(:policy) { double("Policy") }

  describe "#initialize" do
    it "creates a permission with a name" do
      permission = Vauban::Permission.new(:view)
      expect(permission.name).to eq(:view)
    end

    it "initializes empty rules array" do
      permission = Vauban::Permission.new(:view)
      expect(permission.rules).to eq([])
    end

    it "evaluates block if provided" do
      permission = Vauban::Permission.new(:view) do
        allow_if { |r| r.public? }
      end
      expect(permission.rules.length).to eq(1)
      expect(permission.rules.first.type).to eq(:allow)
    end
  end

  describe "#allow_if" do
    it "adds an allow rule" do
      permission = Vauban::Permission.new(:view)
      permission.allow_if { |r| r.public? }
      expect(permission.rules.length).to eq(1)
      expect(permission.rules.first.type).to eq(:allow)
    end

    it "allows multiple allow rules" do
      permission = Vauban::Permission.new(:view)
      permission.allow_if { |r| r.public? }
      permission.allow_if { |r, u| r.owner == u }
      expect(permission.rules.length).to eq(2)
      expect(permission.rules.all? { |r| r.type == :allow }).to be true
    end
  end

  describe "#deny_if" do
    it "adds a deny rule" do
      permission = Vauban::Permission.new(:view)
      permission.deny_if { |r| r.archived? }
      expect(permission.rules.length).to eq(1)
      expect(permission.rules.first.type).to eq(:deny)
    end

    it "allows multiple deny rules" do
      permission = Vauban::Permission.new(:view)
      permission.deny_if { |r| r.archived? }
      permission.deny_if { |r| r.deleted? }
      expect(permission.rules.length).to eq(2)
      expect(permission.rules.all? { |r| r.type == :deny }).to be true
    end
  end

  describe "#allowed?" do
    context "with allow rules" do
      it "returns true if any allow rule passes" do
        permission = Vauban::Permission.new(:view) do
          allow_if { |r| r.public? }
        end

        public_resource = double("Resource", public?: true)
        expect(permission.allowed?(public_resource, user)).to be true
      end

      it "returns false if no allow rules pass" do
        permission = Vauban::Permission.new(:view) do
          allow_if { |r| r.public? }
        end

        private_resource = double("Resource", public?: false)
        expect(permission.allowed?(private_resource, user)).to be false
      end

      it "returns true if first allow rule passes" do
        permission = Vauban::Permission.new(:view) do
          allow_if { |r| r.public? }
          allow_if { |r, u| r.owner == u }
        end

        public_resource = double("Resource", public?: true, owner: user)
        expect(permission.allowed?(public_resource, user)).to be true
      end

      it "checks all allow rules until one passes" do
        permission = Vauban::Permission.new(:view) do
          allow_if { |r| r.public? }
          allow_if { |r, u| r.owner == u }
        end

        owned_resource = double("Resource", public?: false, owner: user)
        expect(permission.allowed?(owned_resource, user)).to be true
      end
    end

    context "with deny rules" do
      it "returns false if any deny rule passes" do
        permission = Vauban::Permission.new(:view) do
          deny_if { |r| r.archived? }
          allow_if { |r| r.public? }
        end

        archived_resource = double("Resource", archived?: true, public?: true)
        expect(permission.allowed?(archived_resource, user)).to be false
      end

      it "checks deny rules before allow rules" do
        permission = Vauban::Permission.new(:view) do
          deny_if { |r| r.archived? }
          allow_if { |r| r.public? }
        end

        archived_public_resource = double("Resource", archived?: true, public?: true)
        expect(permission.allowed?(archived_public_resource, user)).to be false
      end

      it "allows access if deny rule fails but allow rule passes" do
        permission = Vauban::Permission.new(:view) do
          deny_if { |r| r.archived? }
          allow_if { |r| r.public? }
        end

        public_resource = double("Resource", archived?: false, public?: true)
        expect(permission.allowed?(public_resource, user)).to be true
      end
    end

    context "with context" do
      it "passes context to rule blocks" do
        permission = Vauban::Permission.new(:view) do
          allow_if { |r, u, ctx| ctx[:admin] == true }
        end

        context = { admin: true }
        expect(permission.allowed?(resource, user, context: context)).to be true
      end

      it "works without context" do
        permission = Vauban::Permission.new(:view) do
          allow_if { |r| r.public? }
        end

        public_resource = double("Resource", public?: true)
        expect(permission.allowed?(public_resource, user, context: {})).to be true
      end
    end

    context "with policy instance" do
      it "evaluates rules in policy context when policy provided" do
        permission = Vauban::Permission.new(:view) do
          allow_if { |r| evaluate_condition(:is_public, r, user, {}) }
        end

        policy_instance = double("Policy")
        allow(policy_instance).to receive(:instance_exec).and_return(true)

        expect(permission.allowed?(resource, user, policy: policy_instance)).to be true
        expect(policy_instance).to have_received(:instance_exec)
      end

      it "calls block directly when no policy provided" do
        permission = Vauban::Permission.new(:view) do
          allow_if { |r| r.public? }
        end

        public_resource = double("Resource", public?: true)
        expect(permission.allowed?(public_resource, user)).to be true
      end
    end

    context "with no rules" do
      it "defaults to deny" do
        permission = Vauban::Permission.new(:view)
        expect(permission.allowed?(resource, user)).to be false
      end
    end

    context "error handling" do
      it "returns false when rule evaluation raises an error" do
        permission = Vauban::Permission.new(:view) do
          allow_if { |r| raise StandardError, "Test error" }
        end

        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          allow(Rails.logger).to receive(:error)
        end

        expect(permission.allowed?(resource, user)).to be false

        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          expect(Rails.logger).to have_received(:error) do |message|
            expect(message).to include("Vauban permission error")
            expect(message).to include(":view")
            expect(message).to include("allow")
            expect(message).to include("Test error")
          end
        end
      end

      it "continues checking other rules after error" do
        permission = Vauban::Permission.new(:view) do
          allow_if { |r| raise StandardError, "Test error" }
          allow_if { |r| r.public? }
        end

        public_resource = double("Resource", public?: true)

        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          allow(Rails.logger).to receive(:error)
        end

        expect(permission.allowed?(public_resource, user)).to be true
      end

      it "handles errors in deny rules" do
        permission = Vauban::Permission.new(:view) do
          deny_if { |r| raise StandardError, "Test error" }
          allow_if { |r| r.public? }
        end

        public_resource = double("Resource", public?: true)

        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          allow(Rails.logger).to receive(:error)
        end

        # Error in deny rule should not prevent allow rule from passing
        expect(permission.allowed?(public_resource, user)).to be true
      end

      it "does not log errors when Rails is not available" do
        permission = Vauban::Permission.new(:view) do
          allow_if { |r| raise StandardError, "Test error" }
        end

        # Should not raise even without Rails
        expect { permission.allowed?(resource, user) }.not_to raise_error
      end
    end

    context "complex scenarios" do
      it "handles multiple deny and allow rules correctly" do
        permission = Vauban::Permission.new(:edit) do
          deny_if { |r| r.archived? }
          deny_if { |r| r.deleted? }
          allow_if { |r, u| r.owner == u }
          allow_if { |r, u| r.collaborators.include?(u) }
        end

        # Owner can edit non-archived document
        owned_resource = double("Resource", archived?: false, deleted?: false, owner: user)
        expect(permission.allowed?(owned_resource, user)).to be true

        # Cannot edit archived document even if owner
        archived_resource = double("Resource", archived?: true, deleted?: false, owner: user)
        expect(permission.allowed?(archived_resource, user)).to be false

        # Cannot edit deleted document
        deleted_resource = double("Resource", archived?: false, deleted?: true, owner: user)
        expect(permission.allowed?(deleted_resource, user)).to be false
      end

      it "handles rules with different arities" do
        permission = Vauban::Permission.new(:view) do
          allow_if { |r| r.public? }
          allow_if { |r, u| r.owner == u }
          allow_if { |r, u, ctx| ctx[:admin] == true }
        end

        # Test with resource only
        public_resource = double("Resource", public?: true)
        expect(permission.allowed?(public_resource, user)).to be true

        # Test with resource and user
        owned_resource = double("Resource", public?: false, owner: user)
        expect(permission.allowed?(owned_resource, user)).to be true

        # Test with resource, user, and context
        private_resource = double("Resource", public?: false, owner: double("OtherUser"))
        context = { admin: true }
        expect(permission.allowed?(private_resource, user, context: context)).to be true
      end
    end
  end
end
