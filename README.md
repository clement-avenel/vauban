# Vauban

**Relationship-based authorization for Rails**

Vauban is a Rails-first authorization gem that uses Relationship-Based Access Control (ReBAC) with a readable DSL, built-in caching, and batch operations.

Named after [Sébastien Le Prestre de Vauban](https://en.wikipedia.org/wiki/Sébastien_Le_Prestre_de_Vauban), the master builder of citadels and fortifications, Vauban provides robust authorization defenses for your Rails application.

> 📚 **New to ReBAC?** Check out [CONCEPTS.md](./CONCEPTS.md) for a deep dive into Relationship-Based Access Control, why it matters, and how Vauban implements it.
> 
> 🔄 **Migrating from CanCanCan or Pundit?** Check out [MIGRATION.md](./MIGRATION.md) for step-by-step migration guides with side-by-side code comparisons.

## Features

- **Relationship-Based**: Model authorization through relationships, not just roles
- **Readable DSL**: Policies that are easy to understand and maintain
- **Performance**: Built-in caching and batch operations
- **Rails Integration**: Controller helpers, view helpers, generators, and Railtie auto-configuration

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'vauban'
```

And then execute:

```bash
$ bundle install
```

Run the install generator to create an initializer and example policy:

```bash
$ rails generate vauban:install
```

Or generate a policy for a specific model:

```bash
$ rails generate vauban:policy Article
```

## Quick Start

### 1. Define a Policy

```ruby
# app/policies/document_policy.rb
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
    deny_if { |doc| doc.archived? }
    allow_if { |doc, user| doc.owner == user }
  end

  # Optional: Define scopes for efficient queries (or use allow_where below for auto-scope)
  scope :view do |user, context|
    Document.left_joins(:document_collaborations)
      .where(public: true)
      .or(Document.left_joins(:document_collaborations).where(owner: user))
      .or(Document.left_joins(:document_collaborations).where(document_collaborations: { user_id: user.id }))
      .distinct
  end
end
```

### 2. Use in Controllers

```ruby
class DocumentsController < ApplicationController
  def show
    @document = Document.find(params[:id])
    authorize! :view, @document
  end

  def update
    @document = Document.find(params[:id])
    authorize! :edit, @document
    # ... update logic
  end

  def index
    @documents = Vauban.accessible_by(current_user, :view, Document)
  end
end
```

Controller helpers (`authorize!`, `can?`, `cannot?`) are automatically included via the Railtie.

### 3. Use in Views

```erb
<% if can?(:edit, @document) %>
  <%= link_to "Edit", edit_document_path(@document) %>
<% end %>

<% if can?(:delete, @document) %>
  <%= link_to "Delete", document_path(@document), method: :delete %>
<% end %>
```

### 4. Batch Permission Checks

When you need permissions for multiple resources (e.g., rendering a list), use batch operations to avoid N+1 permission checks:

```ruby
permissions = Vauban.batch_permissions(current_user, @documents)
# => { #<Document id:1> => {"view" => true, "edit" => true, "delete" => false}, ... }
```

## Configuration

```ruby
# config/initializers/vauban.rb
Vauban.configure do |config|
  config.current_user_method = :current_user  # Method name on controllers (default: :current_user)
  config.cache_store = Rails.cache             # Set by Railtie automatically (default: Rails.cache)
  config.cache_ttl = 3600                      # Cache TTL in seconds (default: 3600)
  config.policy_paths = [                      # Where to discover policies (default shown)
    "app/policies/**/*_policy.rb",
    "packs/*/app/policies/**/*_policy.rb"
  ]
end
```

### Caching

Vauban includes built-in caching for permission checks:

- **Permission checks** (`Vauban.can?`) are cached by user, action, resource, and context
- **Policy lookups** (`Registry.policy_for`) are cached by resource class
- **Batch operations** automatically benefit from caching

```ruby
# Clear all cached permissions
Vauban.clear_cache!

# Clear cache for a specific resource (e.g., after update)
Vauban.clear_cache_for_resource!(document)

# Clear cache for a specific user (e.g., after role change)
Vauban.clear_cache_for_user!(user)
```

To disable caching:

```ruby
Vauban.configure do |config|
  config.cache_store = nil
end
```

## API

### Core Methods

| Method | Description |
|--------|-------------|
| `Vauban.can?(user, action, resource, context: {})` | Returns `true`/`false` |
| `Vauban.authorize(user, action, resource, context: {})` | Returns `true` or raises `Vauban::Unauthorized` |
| `Vauban.all_permissions(user, resource, context: {})` | Returns `{"view" => true, "edit" => false, ...}` |
| `Vauban.batch_permissions(user, resources, context: {})` | Returns `{resource => permissions_hash, ...}` |
| `Vauban.accessible_by(user, action, resource_class, context: {})` | Returns scoped ActiveRecord relation |

### Policy DSL

| Method | Description |
|--------|-------------|
| `resource Klass` | Declares which model this policy governs |
| `permission :name { ... }` | Defines a permission with allow/deny rules |
| `allow_if { \|resource, user, context\| ... }` | Grants access if block returns truthy |
| `deny_if { \|resource, user, context\| ... }` | Denies access if block returns truthy (checked before allow rules) |
| `allow_where { \|user, context\| hash }` | Declarative conditions: same hash powers `can?` (record match) and `accessible_by` (SQL scope). E.g. `{ public: true }` or `{ owner_id: user.id }`. No separate scope block needed. |
| `scope :action { \|user, context\| ... }` | Defines a scope for `accessible_by` queries |
| `relationship :name { ... }` | Defines a reusable relationship block |
| `condition :name { \|resource, user, context\| ... }` | Defines a reusable condition block |

## Testing Your Policies

Vauban ships with RSpec matchers. Add to your `spec_helper.rb` or `rails_helper.rb`:

```ruby
require "vauban/rspec"
```

Then use `be_able_to` to test through the full authorization stack:

```ruby
RSpec.describe DocumentPolicy do
  let(:user) { create(:user) }
  let(:document) { create(:document, owner: user) }

  it { expect(user).to be_able_to(:view, document) }
  it { expect(user).to be_able_to(:edit, document) }
  it { expect(other_user).not_to be_able_to(:edit, document) }

  it { expect(user).to be_able_to(:admin, document).with_context(admin: true) }
end
```

Or use `permit` to test a policy class directly (bypasses Registry and cache):

```ruby
RSpec.describe DocumentPolicy do
  let(:user) { create(:user) }
  let(:document) { create(:document, owner: user) }

  it { expect(DocumentPolicy).to permit(:view).for(user, document) }
  it { expect(DocumentPolicy).not_to permit(:edit).for(other_user, document) }
  it { expect(DocumentPolicy).to permit(:admin).for(user, document).with_context(admin: true) }
end
```

## Development

### Requirements

- Ruby >= 3.0.0
- Rails >= 6.0

### Setup

```bash
bundle install
```

### Testing

```bash
# Run all tests
bundle exec rspec

# Run only unit tests (no Rails required)
bundle exec rspec spec/vauban/

# Run only integration tests (requires dummy app)
bundle exec rspec spec/integration/
```

### Dummy App

The dummy Rails app (`spec/dummy/`) serves as both a showcase and integration test harness:

```bash
cd spec/dummy
bundle install
rails db:create db:migrate db:seed
rails server
```

### Pre-commit Hooks

```bash
chmod +x bin/install-pre-commit
./bin/install-pre-commit
```

## Documentation

- **[CONCEPTS.md](./CONCEPTS.md)** - Deep dive into ReBAC and Vauban's design philosophy
- **[MIGRATION.md](./MIGRATION.md)** - Migration guides from CanCanCan and Pundit
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Technical architecture and implementation details
- **[EXAMPLES.md](./EXAMPLES.md)** - Comprehensive code examples and use cases
- **[TESTING.md](./TESTING.md)** - Testing guide and best practices
- **[SECURITY.md](./SECURITY.md)** - Security policy and responsible disclosure

## Roadmap

### Medium Priority
- **Developer Experience**: Debug mode with detailed logging, policy validation
- **Documentation**: Performance benchmarks

### Nice to Have
- **Advanced Features**: Permission inheritance/composition, time-based permissions
- **Monitoring**: Metrics (permission check counts, cache hit rates)

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/clement-avenel/vauban).

## Security

See [SECURITY.md](./SECURITY.md) for our responsible disclosure policy.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
