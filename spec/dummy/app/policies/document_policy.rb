# frozen_string_literal: true

# Relationship-based access comes only from the Vauban relationship store.
# Owner/editor/viewer are synced into the store via grants_relation on Document and DocumentCollaboration.
class DocumentPolicy < Vauban::Policy
  resource Document

  permission :view do
    allow_if { |doc, user| Vauban.relation?(user, :owner, doc) }
    allow_if { |doc, user| Vauban.relation?(user, :editor, doc) }
    allow_if { |doc, user| Vauban.relation?(user, :viewer, doc) }
    allow_if { |doc, user| viewer_via_team?(user, doc) }
    allow_if { |doc| doc.public? }
  end

  permission :edit do
    allow_if { |doc, user| Vauban.relation?(user, :owner, doc) }
    allow_if { |doc, user| Vauban.relation?(user, :editor, doc) }
    allow_if { |doc, user| editor_via_team?(user, doc) }
  end

  permission :delete do
    deny_if { |doc| doc.archived? }
    allow_if { |doc, user| Vauban.relation?(user, :owner, doc) }
  end

  permission :create do
    allow_if { |doc, user| user.present? }
  end

  scope :view do |user, _context|
    direct_ids = DocumentPolicy.doc_ids_from_direct_relations(user)
    team_doc_ids = DocumentPolicy.doc_ids_visible_to_user_via_teams(user)
    all_ids = (direct_ids + team_doc_ids).uniq
    if all_ids.any?
      Document.where(public: true).or(Document.where(id: all_ids)).distinct
    else
      Document.where(public: true).distinct
    end
  end

  def self.doc_ids_from_direct_relations(user)
    %i[owner editor viewer].flat_map do |rel|
      Vauban.objects_with(user, rel, object_type: Document).pluck(:object_id)
    end.uniq
  end

  def self.doc_ids_visible_to_user_via_teams(user)
    team_ids = Vauban.objects_with(user, :member, object_type: Team).pluck(:object_id).uniq
    return [] if team_ids.empty?

    Vauban::Relationship.where(
      object_type: "Document",
      relation: [ "viewer", "editor" ],
      subject_type: "Team",
      subject_id: team_ids
    ).distinct.pluck(:object_id)
  end

  private

  def viewer_via_team?(user, doc)
    teams_user_is_member_of(user).any? { |team| Vauban.relation?(team, :viewer, doc) || Vauban.relation?(team, :editor, doc) }
  end

  def editor_via_team?(user, doc)
    teams_user_is_member_of(user).any? { |team| Vauban.relation?(team, :editor, doc) }
  end

  def teams_user_is_member_of(user)
    Vauban.objects_with(user, :member, object_type: Team).map(&:object).uniq
  end
end
