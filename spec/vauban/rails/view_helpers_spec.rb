# frozen_string_literal: true

require "rails_helper"

RSpec.describe Vauban::Rails::ViewHelpers do
  include Vauban::Rails::ViewHelpers

  let(:user) { User.create!(email: "test@example.com", name: "Test User") }
  let(:other_user) { User.create!(email: "other@example.com", name: "Other User") }
  let(:document) { Document.create!(title: "Test Doc", owner: user, public: false) }

  describe "#can?" do
    before do
      allow(self).to receive(:current_user).and_return(user)
    end

    it "returns true for allowed permissions" do
      expect(can?(:view, document)).to be true
    end

    it "returns false for denied permissions" do
      allow(self).to receive(:current_user).and_return(other_user)
      expect(can?(:view, document)).to be false
    end

    it "uses configured current_user_method" do
      Vauban.configure do |config|
        config.current_user_method = :authenticated_user
      end

      allow(self).to receive(:authenticated_user).and_return(user)
      expect(can?(:view, document)).to be true

      # Reset
      Vauban.configure do |config|
        config.current_user_method = :current_user
      end
    end

    it "passes context to permission check" do
      allow(Vauban).to receive(:can?).and_return(true)
      can?(:view, document, context: { admin: true })
      expect(Vauban).to have_received(:can?).with(user, :view, document, context: { admin: true })
    end

    it "works with public documents" do
      public_doc = Document.create!(title: "Public Doc", owner: user, public: true)
      allow(self).to receive(:current_user).and_return(other_user)
      expect(can?(:view, public_doc)).to be true
    end
  end

  describe "#cannot?" do
    before do
      allow(self).to receive(:current_user).and_return(user)
    end

    it "returns false when user can perform action" do
      expect(cannot?(:view, document)).to be false
    end

    it "returns true when user cannot perform action" do
      allow(self).to receive(:current_user).and_return(other_user)
      expect(cannot?(:view, document)).to be true
    end

    it "is the inverse of can?" do
      expect(cannot?(:view, document)).to eq(!can?(:view, document))
    end

    it "passes context to can? method" do
      allow(self).to receive(:current_user).and_return(other_user)
      allow(Vauban).to receive(:can?).and_return(false)
      cannot?(:view, document, context: { admin: true })
      expect(Vauban).to have_received(:can?).with(other_user, :view, document, context: { admin: true })
    end
  end

  describe "integration with views" do
    before do
      allow(self).to receive(:current_user).and_return(user)
    end

    it "can be used in ERB templates" do
      # Simulate ERB usage
      output = if can?(:edit, document)
        "Edit Link"
      else
        "No Edit"
      end
      expect(output).to eq("Edit Link")
    end

    it "works with cannot? in conditional blocks" do
      output = if cannot?(:delete, document)
        "No Delete"
      else
        "Delete Link"
      end
      # Document owner can delete (based on DocumentPolicy)
      expect(output).to eq("Delete Link")
    end
  end

  describe "error handling" do
    it "handles missing current_user gracefully" do
      # If current_user method doesn't exist, send will raise NoMethodError
      allow(self).to receive(:send).and_call_original
      allow(self).to receive(:send).with(:current_user).and_raise(NoMethodError, "undefined method `current_user'")
      expect { can?(:view, document) }.to raise_error(NoMethodError)
    end

    it "handles PolicyNotFound errors gracefully" do
      allow(self).to receive(:current_user).and_return(user)
      allow(Vauban::Registry).to receive(:policy_for).and_return(nil)
      expect(can?(:view, document)).to be false
    end
  end
end
