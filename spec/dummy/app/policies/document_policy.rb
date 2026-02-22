# frozen_string_literal: true

class DocumentPolicy < Vauban::Policy
  resource Document

  permission :view do
    allow_if { |doc, user| doc.owner == user }
    allow_if { |doc, user| doc.collaborators.include?(user) }
    allow_if { |doc| doc.public? }
  end

  permission :edit do
    allow_if { |doc, user| doc.owner == user }
    allow_if { |doc, user| 
      collaboration = doc.collaboration_for(user)
      collaboration && collaboration.permissions.include?(:edit)
    }
  end

  permission :delete do
    allow_if { |doc, user| doc.owner == user && !doc.archived? }
  end

  permission :create do
    # Allow any authenticated user to create documents
    allow_if { |doc, user| user.present? }
  end

  # Optional: Define scopes for efficient queries
  scope :view do |user, _context|
    Document.left_joins(:document_collaborations)
      .where(
        "documents.public = ? OR documents.owner_id = ? OR document_collaborations.user_id = ?",
        true, user.id, user.id
      )
      .distinct
  end
end
