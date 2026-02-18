# frozen_string_literal: true

require "rails_helper"

RSpec.describe Vauban::Rails::ControllerHelpers, type: :controller do
  controller(ApplicationController) do
    include Vauban::Rails::ControllerHelpers

    def index
      authorize! :view, Document.first
      render plain: "OK"
    end

    def show
      if can?(:view, Document.first)
        render plain: "OK"
      else
        render plain: "Forbidden", status: :forbidden
      end
    end

    def edit
      authorize! :edit, Document.first
      render plain: "OK"
    end

    def update
      if cannot?(:edit, Document.first)
        render plain: "Forbidden", status: :forbidden
      else
        render plain: "OK"
      end
    end
  end

  let(:user) { User.create!(email: "test@example.com", name: "Test User") }
  let(:other_user) { User.create!(email: "other@example.com", name: "Other User") }
  let(:document) { Document.create!(title: "Test Doc", owner: user, public: false) }

  describe "module inclusion" do
    it "includes helper methods" do
      expect(controller.class.instance_methods).to include(:authorize!, :can?, :cannot?)
    end

    it "makes can? and cannot? available as helper methods" do
      # Check that helper_method was called during inclusion
      # In Rails, helper_methods are registered via helper_method macro
      expect(controller.class.instance_methods).to include(:can?, :cannot?)
      # These methods should be callable from views
      expect(controller.respond_to?(:can?, true)).to be true
      expect(controller.respond_to?(:cannot?, true)).to be true
    end
  end

  describe "#authorize!" do
    before do
      routes.draw do
        get "index" => "anonymous#index"
      end
    end

    it "allows authorized actions" do
      allow(controller).to receive(:current_user).and_return(user)
      allow(Document).to receive(:first).and_return(document)
      get :index
      expect(response).to have_http_status(:success)
    end

    it "raises Unauthorized for unauthorized actions" do
      # Create a fresh private document owned by user, not other_user
      private_doc = Document.create!(title: "Private Test Doc", owner: user, public: false)
      private_doc.reload

      # Verify the document setup
      expect(private_doc.owner).to eq(user)
      expect(private_doc.public).to be false
      expect(private_doc.collaborators).not_to include(other_user)

      # Verify authorization will fail for other_user
      expect(Vauban.can?(other_user, :view, private_doc)).to be false

      # Stub Document.first to return our private document
      allow(Document).to receive(:first).and_return(private_doc)
      allow(controller).to receive(:current_user).and_return(other_user)

      # ApplicationController has rescue_from Vauban::Unauthorized that redirects
      # So we check for the redirect instead of the exception
      get :index
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to match(/not authorized/i)
    end

    it "uses configured current_user_method" do
      Vauban.configure do |config|
        config.current_user_method = :authenticated_user
      end

      allow(controller).to receive(:authenticated_user).and_return(user)
      allow(Document).to receive(:first).and_return(document)
      get :index
      expect(response).to have_http_status(:success)

      # Reset
      Vauban.configure do |config|
        config.current_user_method = :current_user
      end
    end

    it "passes context to authorization" do
      allow(controller).to receive(:current_user).and_return(user)
      allow(Document).to receive(:first).and_return(document)
      allow(Vauban).to receive(:authorize).and_return(true)
      get :index
      expect(Vauban).to have_received(:authorize).with(user, :view, document, context: {})
    end
  end

  describe "#can?" do
    before do
      routes.draw do
        get "show" => "anonymous#show"
      end
      allow(controller).to receive(:current_user).and_return(user)
      allow(Document).to receive(:first).and_return(document)
    end

    it "returns true for allowed permissions" do
      get :show
      expect(response).to have_http_status(:success)
      expect(response.body).to eq("OK")
    end

    it "returns false for denied permissions" do
      allow(controller).to receive(:current_user).and_return(other_user)
      get :show
      expect(response).to have_http_status(:forbidden)
      expect(response.body).to eq("Forbidden")
    end

    it "uses configured current_user_method" do
      Vauban.configure do |config|
        config.current_user_method = :authenticated_user
      end

      allow(controller).to receive(:authenticated_user).and_return(user)
      get :show
      expect(response).to have_http_status(:success)

      # Reset
      Vauban.configure do |config|
        config.current_user_method = :current_user
      end
    end

    it "passes context to permission check" do
      allow(Vauban).to receive(:can?).and_return(true)
      get :show
      expect(Vauban).to have_received(:can?).with(user, :view, document, context: {})
    end
  end

  describe "#cannot?" do
    before do
      routes.draw do
        get "update" => "anonymous#update"
      end
      allow(controller).to receive(:current_user).and_return(user)
      allow(Document).to receive(:first).and_return(document)
    end

    it "returns false when user can perform action" do
      get :update
      expect(response).to have_http_status(:success)
      expect(response.body).to eq("OK")
    end

    it "returns true when user cannot perform action" do
      allow(controller).to receive(:current_user).and_return(other_user)
      get :update
      expect(response).to have_http_status(:forbidden)
      expect(response.body).to eq("Forbidden")
    end

    it "is the inverse of can?" do
      allow(controller).to receive(:current_user).and_return(user)
      expect(controller.cannot?(:view, document)).to eq(!controller.can?(:view, document))
    end
  end

  describe "error handling" do
    before do
      routes.draw do
        get "index" => "anonymous#index"
      end
      allow(Document).to receive(:first).and_return(document)
    end

    it "handles missing current_user gracefully" do
      # If current_user method doesn't exist, send will raise NoMethodError
      # We need to prevent the method from being called
      allow(controller).to receive(:send).and_call_original
      allow(controller).to receive(:send).with(:current_user).and_raise(NoMethodError, "undefined method `current_user'")
      expect {
        get :index
      }.to raise_error(NoMethodError)
    end

    it "handles PolicyNotFound errors" do
      allow(controller).to receive(:current_user).and_return(user)
      allow(Vauban::Registry).to receive(:policy_for).and_return(nil)
      allow(Vauban).to receive(:authorize).and_raise(Vauban::PolicyNotFound, "No policy found")

      expect {
        get :index
      }.to raise_error(Vauban::PolicyNotFound)
    end
  end
end
