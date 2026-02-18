# frozen_string_literal: true

# Helper to set up dummy app models and policies for testing
# This is used when the dummy app files don't exist yet
module DummyAppSetup
  def self.setup_models
    return unless defined?(Rails) && Rails.env.test?

    # Try to load from dummy app first
    dummy_app_path = File.expand_path("../dummy", __dir__)
    if Dir.exist?(dummy_app_path)
      # Models should be auto-loaded from dummy app
      return
    end

    # Fallback: Create models dynamically if dummy app doesn't exist
    unless defined?(User)
      Object.const_set("User", Class.new(ActiveRecord::Base) do
        has_many :documents, class_name: "Document", foreign_key: "owner_id"
        has_many :document_collaborations, class_name: "DocumentCollaboration", foreign_key: "user_id"
        has_many :collaborated_documents, through: :document_collaborations, source: :document
      end)
    end

    unless defined?(Document)
      Object.const_set("Document", Class.new(ActiveRecord::Base) do
        belongs_to :owner, class_name: "User", foreign_key: "owner_id"
        has_many :document_collaborations, class_name: "DocumentCollaboration", dependent: :destroy
        has_many :collaborators, through: :document_collaborations, source: :user

        def public?
          public
        end

        def collaboration_permissions(user)
          collaboration = document_collaborations.find_by(user: user)
          collaboration ? collaboration.permissions : []
        end
      end)
    end

    unless defined?(DocumentCollaboration)
      Object.const_set("DocumentCollaboration", Class.new(ActiveRecord::Base) do
        belongs_to :document
        belongs_to :user

        serialize :permissions, Array
      end)
    end
  end

  def self.setup_policies
    return unless defined?(Rails) && Rails.env.test?

    # Policies should be auto-loaded from dummy app
    # But ensure they're registered
    Vauban::Registry.discover_and_register
  end

  def self.setup_all
    setup_models
    setup_policies
  end
end
