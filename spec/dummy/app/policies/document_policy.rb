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
      doc.collaborators.include?(user) && 
      doc.collaboration_permissions(user).include?(:edit)
    }
  end

  permission :delete do
    allow_if { |doc, user| doc.owner == user && !doc.archived? }
  end

  # Optional: Define scopes for efficient queries
  scope :view do |user|
    # Use left joins to make all queries structurally compatible
    Document.left_joins(:document_collaborations)
      .where(public: true)
      .or(Document.left_joins(:document_collaborations).where(owner: user))
      .or(Document.left_joins(:document_collaborations).where(document_collaborations: { user_id: user.id }))
      .distinct
  end
end
