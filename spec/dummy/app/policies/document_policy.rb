# frozen_string_literal: true

# ReBAC: relations and permissions are derived from the relationship store.
# Schema: editor implies viewer; owner implies editor and viewer.
# Indirect: viewer/editor on Document can be satisfied via (user, member, team) and (team, viewer|editor, doc).
class DocumentPolicy < Vauban::Policy
  resource Document

  relation :viewer
  relation :viewer, via: { member: Team }
  relation :editor, requires: [:viewer]
  relation :editor, via: { member: Team }
  relation :owner, requires: [:editor, :viewer]

  permission :view, relation: :viewer do
    allow_if { |doc| doc.public? }
  end

  permission :edit, relation: :editor

  permission :delete do
    deny_if { |doc| doc.archived? }
    allow_if { |doc, user| Vauban.relation?(user, :owner, doc) }
  end

  permission :create do
    allow_if { |_doc, user| user.present? }
  end

  scope :view, relation: :viewer do |user, _context|
    Document.where(public: true)
  end
end
