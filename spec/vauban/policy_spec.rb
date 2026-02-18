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
      expect(policy.allowed?(:view, document, user)).to be true
    end
  end
end

