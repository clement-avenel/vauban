# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Vauban Rails Integration", type: :request do
  before do
    DummyAppSetup.setup_all
  end

  let(:user) { User.create!(email: "test@example.com", name: "Test User") }
  let(:other_user) { User.create!(email: "other@example.com", name: "Other User") }
  let(:document) { Document.create!(title: "Test Doc", owner: user, public: false) }

  describe "Controller helpers" do
    it "includes authorization helpers" do
      controller_class = Class.new(ActionController::Base) do
        include Vauban::Rails::ControllerHelpers
      end

      expect(controller_class.instance_methods).to include(:authorize!, :can?, :cannot?)
    end
  end

  describe "Permission checking" do
    it "allows owner to view document" do
      expect(Vauban.can?(user, :view, document)).to be true
    end

    it "allows owner to edit document" do
      expect(Vauban.can?(user, :edit, document)).to be true
    end

    it "denies other user from viewing private document" do
      expect(Vauban.can?(other_user, :view, document)).to be false
    end

    it "allows viewing public documents" do
      public_doc = Document.create!(title: "Public Doc", owner: user, public: true)
      expect(Vauban.can?(other_user, :view, public_doc)).to be true
    end
  end
end

