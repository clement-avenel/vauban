# frozen_string_literal: true

# Clear existing data
DocumentCollaboration.destroy_all
Document.destroy_all
User.destroy_all

# Create users
alice = User.create!(
  email: "alice@example.com",
  name: "Alice"
)

bob = User.create!(
  email: "bob@example.com",
  name: "Bob"
)

charlie = User.create!(
  email: "charlie@example.com",
  name: "Charlie"
)

# Create documents owned by Alice
alice_doc_public = Document.create!(
  title: "Alice's Public Document",
  content: "This is a public document owned by Alice. Anyone can view it!",
  owner: alice,
  public: true
)

alice_doc_private = Document.create!(
  title: "Alice's Private Document",
  content: "This is a private document owned by Alice. Only Alice and collaborators can view it.",
  owner: alice,
  public: false
)

alice_doc_archived = Document.create!(
  title: "Alice's Archived Document",
  content: "This document is archived and cannot be deleted.",
  owner: alice,
  public: false,
  archived: true
)

# Create documents owned by Bob
bob_doc_public = Document.create!(
  title: "Bob's Public Document",
  content: "This is a public document owned by Bob. Anyone can view it!",
  owner: bob,
  public: true
)

bob_doc_private = Document.create!(
  title: "Bob's Private Document",
  content: "This is a private document owned by Bob. Only Bob can view it.",
  owner: bob,
  public: false
)

# Create a document with collaboration
collaboration_doc = Document.create!(
  title: "Collaboration Example",
  content: "This document demonstrates collaboration. Alice owns it, but Bob is a collaborator with edit permissions.",
  owner: alice,
  public: false
)

# Add Bob as a collaborator with edit permissions
bob_collaboration = DocumentCollaboration.create!(
  document: collaboration_doc,
  user: bob
)
bob_collaboration.document_collaboration_permissions.create!(permission: "edit")

# Add Charlie as a collaborator with view-only permissions
charlie_collaboration = DocumentCollaboration.create!(
  document: collaboration_doc,
  user: charlie
)
charlie_collaboration.document_collaboration_permissions.create!(permission: "view")

puts "✅ Seed data created!"
puts ""
puts "Users:"
puts "  - Alice (#{alice.email})"
puts "  - Bob (#{bob.email})"
puts "  - Charlie (#{charlie.email})"
puts ""
puts "Documents:"
puts "  - Alice's Public Document (public, owned by Alice)"
puts "  - Alice's Private Document (private, owned by Alice)"
puts "  - Alice's Archived Document (archived, owned by Alice)"
puts "  - Bob's Public Document (public, owned by Bob)"
puts "  - Bob's Private Document (private, owned by Bob)"
puts "  - Collaboration Example (private, owned by Alice, Bob can edit, Charlie can view)"
puts ""
puts "💡 Try switching users in the UI to see how permissions change!"
