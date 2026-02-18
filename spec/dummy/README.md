# Vauban Dummy App

This is a **showcase Rails application** demonstrating how to use Vauban for authorization.

## Purpose

- **Showcase**: See real examples of Vauban in action
- **Testing**: Used for integration tests
- **Learning**: Learn how to integrate Vauban into your Rails app

## What's Included

### Models
- `User` - Basic user model
- `Document` - Example resource with ownership and collaboration
- `DocumentCollaboration` - Join table for document collaborators

### Policies
- `DocumentPolicy` - Complete example showing:
  - Relationship-based permissions (owner, collaborators)
  - Public/private document access
  - Permission scopes for efficient queries

### Features Demonstrated
- ✅ Policy definition with relationships
- ✅ Permission rules (`allow_if` blocks)
- ✅ Scopes for query optimization (`Vauban.accessible_by`)
- ✅ Controller helpers (`authorize!`, `can?`)
- ✅ View helpers (`can?`, `cannot?`)
- ✅ Full CRUD operations with authorization
- ✅ User switching to demonstrate different permission scenarios
- ✅ Visual permission indicators in the UI

## Quick Start

```bash
# Install dependencies
bundle install

# Set up database and seed demo data
rails db:create db:migrate db:seed

# Start the server
rails server
```

Then visit **http://localhost:3000** to see the demo in action!

### What You'll See

1. **Documents List** - View all documents with permission indicators
2. **User Switcher** - Switch between Alice, Bob, and Charlie to see how permissions change
3. **Document Details** - See authorization checks in action
4. **Create/Edit/Delete** - Try actions to see authorization enforcement

### Seed Data

The seed file creates:
- **3 Users**: Alice, Bob, and Charlie
- **6 Documents**: Mix of public/private, with collaboration examples
- **Collaboration**: One document where Bob can edit and Charlie can view

### Testing Authorization

In Rails console:
```ruby
alice = User.find_by(email: "alice@example.com")
bob = User.find_by(email: "bob@example.com")
doc = Document.find_by(title: "Collaboration Example")

# Test authorization
Vauban.can?(alice, :view, doc)  # => true (owner)
Vauban.can?(bob, :edit, doc)    # => true (collaborator with edit)
Vauban.can?(bob, :delete, doc)  # => false (not owner)
```

## Demo Features

### Interactive UI

- **📄 Documents List** (`/`) - See all documents with permission indicators
- **👤 User Switcher** - Switch users in the navigation to see permission changes
- **🔍 Document Details** (`/documents/:id`) - View document with permission breakdown
- **✏️ Create/Edit** - Try creating and editing documents
- **🗑️ Delete** - Try deleting documents (note: archived documents can't be deleted)

## Exploring the Code

- **Policies**: `app/policies/document_policy.rb` - See how policies are defined with relationships
- **Controllers**: `app/controllers/documents_controller.rb` - See `authorize!` in action
- **Views**: `app/views/documents/` - See `can?` helpers used in views
- **Models**: `app/models/` - See the data models with relationships
- **Configuration**: `config/initializers/vauban.rb` - See how Vauban is configured
- **Seeds**: `db/seeds.rb` - See example data setup

## Notes

- This app uses SQLite for simplicity
- All models and policies are included as examples
