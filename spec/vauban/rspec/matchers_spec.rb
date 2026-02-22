# frozen_string_literal: true

require "spec_helper"
require "vauban/rspec"

RSpec.describe "Vauban RSpec matchers" do
  let(:user) { double("User", id: 1) }
  let(:other_user) { double("User", id: 2) }
  let(:resource_class) { Class.new }
  let(:resource) do
    res = double("Resource", id: 1, owner: user, public?: false)
    allow(res).to receive(:class).and_return(resource_class)
    res
  end
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

      permission :admin do
        allow_if { |_r, _u, ctx| ctx[:admin] == true }
      end
    end
  end

  before do
    stub_const("TestResource", resource_class)
    stub_const("TestResourcePolicy", policy_class)
    Vauban::Registry.register(TestResourcePolicy)
  end

  describe "be_able_to" do
    it "passes when user is authorized" do
      expect(user).to be_able_to(:view, resource)
    end

    it "fails when user is not authorized" do
      expect(other_user).not_to be_able_to(:edit, resource)
    end

    it "supports with_context chain" do
      expect(user).to be_able_to(:admin, resource).with_context(admin: true)
    end

    it "fails with_context when context doesn't match" do
      expect(user).not_to be_able_to(:admin, resource).with_context(admin: false)
    end

    it "produces a clear failure message" do
      matcher = Vauban::RSpec::Matchers::BeAbleTo.new(:edit, resource)
      matcher.matches?(other_user)
      expect(matcher.failure_message).to include(":edit")
    end

    it "produces a clear negated failure message" do
      matcher = Vauban::RSpec::Matchers::BeAbleTo.new(:view, resource)
      matcher.matches?(user)
      expect(matcher.failure_message_when_negated).to include(":view")
    end
  end

  describe "permit" do
    it "passes when policy permits the action" do
      expect(TestResourcePolicy).to permit(:view).for(user, resource)
    end

    it "fails when policy denies the action" do
      expect(TestResourcePolicy).not_to permit(:edit).for(other_user, resource)
    end

    it "supports with_context chain" do
      expect(TestResourcePolicy).to permit(:admin).for(user, resource).with_context(admin: true)
    end

    it "fails with_context when context doesn't match" do
      expect(TestResourcePolicy).not_to permit(:admin).for(user, resource).with_context(admin: false)
    end

    it "produces a clear failure message" do
      matcher = Vauban::RSpec::Matchers::Permit.new(:edit)
      matcher.for(other_user, resource)
      matcher.matches?(TestResourcePolicy)
      expect(matcher.failure_message).to include(":edit")
      expect(matcher.failure_message).to include("TestResourcePolicy")
    end

    it "produces a clear negated failure message" do
      matcher = Vauban::RSpec::Matchers::Permit.new(:view)
      matcher.for(user, resource)
      matcher.matches?(TestResourcePolicy)
      expect(matcher.failure_message_when_negated).to include(":view")
    end
  end
end
