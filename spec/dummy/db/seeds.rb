# frozen_string_literal: true

# Clear existing data
DocumentCollaboration.destroy_all
Document.destroy_all
User.destroy_all
Team.destroy_all

require "vauban/relationship"
Vauban::Relationship.delete_all

# --- Users ---
alice = User.create!(email: "alice@example.com", name: "Alice")
bob   = User.create!(email: "bob@example.com", name: "Bob")
charlie = User.create!(email: "charlie@example.com", name: "Charlie")

# --- Teams (membership lives only in the relationship store — no join table) ---
team_alpha = Team.create!(name: "Alpha")
team_beta  = Team.create!(name: "Beta")

Vauban.grant!(alice, :member, team_alpha)
Vauban.grant!(bob, :member, team_alpha)
Vauban.grant!(bob, :member, team_beta)
Vauban.grant!(charlie, :member, team_beta)

# --- Documents ---
alice_doc_public = Document.create!(
  title: "Alice's Public Document",
  content: "Public. Anyone can view.",
  owner: alice,
  public: true
)

alice_doc_private = Document.create!(
  title: "Alice's Private Document",
  content: "Private. Only Alice (and direct grants).",
  owner: alice,
  public: false
)

bob_doc_public = Document.create!(
  title: "Bob's Public Document",
  content: "Public.",
  owner: bob,
  public: true
)

bob_doc_private = Document.create!(
  title: "Bob's Private Document",
  content: "Private. Bob only — plus Charlie has a direct :viewer grant (share link).",
  owner: bob,
  public: false
)

# Document shared with Team Alpha: only Alpha members (Alice, Bob) can view — no AR collaboration
team_alpha_doc = Document.create!(
  title: "Shared with Team Alpha (ReBAC)",
  content: "This document is not owned by you and has no collaborator row. You can view it because your team (Alpha) has :viewer. user --member--> team --viewer--> document.",
  owner: alice,
  public: false
)
Vauban.grant!(team_alpha, :viewer, team_alpha_doc)

# Document owned by Bob, shared with Team Beta: only Bob (owner) and Beta members (Bob, Charlie) can edit; Alice cannot
team_beta_doc = Document.create!(
  title: "Team Beta can edit (ReBAC)",
  content: "Bob owns it. Team Beta has :editor, so Bob and Charlie can edit via the team. Alice is not in Beta and not the owner, so she cannot edit.",
  owner: bob,
  public: false
)
Vauban.grant!(team_beta, :editor, team_beta_doc)

# Collaboration: Alice owns, Bob and Charlie are collaborators (AR); grants_relation syncs editor/viewer into the store
collaboration_doc = Document.create!(
  title: "Collaboration Example",
  content: "Alice owns it; Bob (edit) and Charlie (view) are collaborators. Synced into the relationship store via grants_relation.",
  owner: alice,
  public: false
)
bob_collab = DocumentCollaboration.create!(document: collaboration_doc, user: bob)
bob_collab.document_collaboration_permissions.create!(permission: "edit")
bob_collab.save!
charlie_collab = DocumentCollaboration.create!(document: collaboration_doc, user: charlie)
charlie_collab.document_collaboration_permissions.create!(permission: "view")
charlie_collab.save!

# Direct grant (e.g. share link): Charlie can view Bob's private doc
Vauban.grant!(charlie, :viewer, bob_doc_private)

puts "✅ Seed data created (ReBAC demo)"
puts ""
puts "Users: Alice, Bob, Charlie"
puts "Teams: Alpha (Alice, Bob), Beta (Bob, Charlie) — membership only in vauban_relationships"
puts ""
puts "Relationship store is the only source for who can view/edit:"
puts "  • Owner/collaborator synced from AR into the store (grants_relation)"
puts "  • Team Alpha has :viewer on «Shared with Team Alpha» → Alice & Bob can view (2-hop)"
puts "  • Team Beta has :editor on «Team Beta can edit» → Bob (owner) & Charlie (via Beta) can edit; Alice cannot"
puts "  • Charlie has direct :viewer on Bob's Private Document (share link)"
puts "💡 Log in as different users and see which documents appear and what you can do."
