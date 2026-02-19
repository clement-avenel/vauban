# Vauban

**Relationship-based authorization for Rails**

Vauban is a Rails-first authorization gem that uses Relationship-Based Access Control (ReBAC) with a readable DSL, comprehensive tooling, and frontend API support.

Named after [Sébastien Le Prestre de Vauban](https://en.wikipedia.org/wiki/S%C3%A9bastien_Le_Prestre_de_Vauban), the master builder of citadels and fortifications, Vauban provides robust authorization defenses for your Rails application.

> 📚 **New to ReBAC?** Check out [CONCEPTS.md](./CONCEPTS.md) for a deep dive into Relationship-Based Access Control, why it matters, and how Vauban implements it.
> 
> 🔄 **Migrating from CanCanCan or Pundit?** Check out [MIGRATION.md](./MIGRATION.md) for step-by-step migration guides with side-by-side code comparisons.

## Features

- 🔗 **Relationship-Based**: Model authorization through relationships, not just roles
- 📝 **Readable DSL**: Policies that are easy to understand and maintain
- 🎯 **Package-Aware**: Built for modular monoliths with Packwerk
- 🚀 **Frontend API**: Efficient permission checking for frontend applications
- ⚡ **Performance**: Built-in caching and batch operations
- 🧪 **Tooling**: Testing framework, visualization, and exploration tools

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'vauban'
```

And then execute:

```bash
$ bundle install
```

## Showcase

Want to see Vauban in action? Check out the **included dummy app** at `spec/dummy/`:

```bash
cd spec/dummy
bundle install
rails db:create db:migrate db:seed
rails server
```

See real examples of policies, models, and authorization in action!

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
    allow_if { |doc, user| doc.owner == user && !doc.archived? }
  end
end
```

### 2. Use in Controllers

```ruby
class DocumentsController < ApplicationController
  include Vauban::Rails::ControllerHelpers
  
  def show
    @document = Document.find(params[:id])
    authorize! :view, @document
  end

  def update
    @document = Document.find(params[:id])
    authorize! :edit, @document
    # ... update logic
  end
end
```

### 3. Use in Views

```erb
<% if can?(:edit, @document) %>
  <%= link_to "Edit", edit_document_path(@document) %>
<% end %>

<% if can?(:delete, @document) %>
  <%= link_to "Delete", document_path(@document), method: :delete %>
<% end %>
```

## Frontend API

### Permission Check Endpoint

```ruby
# app/controllers/api/v1/permissions_controller.rb
class Api::V1::PermissionsController < Api::BaseController
  def check
    resources = params[:resources].map { |r| find_resource(r) }
    permissions = Vauban.batch_permissions(current_user, resources)

    render json: {
      permissions: permissions.map do |resource, perms|
        {
          resource: { type: resource.class.name, id: resource.id },
          permissions: perms
        }
      end
    }
  end
end
```

## Configuration

```ruby
# config/initializers/vauban.rb
Vauban.configure do |config|
  config.current_user_method = :current_user
  config.cache_store = Rails.cache  # Enable caching (default: nil, disabled)
  config.cache_ttl = 1.hour         # Cache TTL for permission checks (default: 1.hour)
  config.frontend_api_enabled = true
  config.frontend_cache_ttl = 5.minutes
end
```

### Caching

Vauban includes built-in caching for permission checks to improve performance:

- **Permission checks** (`Vauban.can?`) are cached by user, action, resource, and context
- **Policy lookups** (`Registry.policy_for`) are cached by resource class
- **Batch operations** automatically benefit from caching

Cache keys include user ID, action, resource class/ID, and context hash, ensuring accurate cache invalidation.

**Cache Management:**

```ruby
# Clear all cached permissions
Vauban.clear_cache!

# Clear cache for a specific resource (useful when resource is updated)
Vauban.clear_cache_for_resource!(document)

# Clear cache for a specific user (useful when user permissions change)
Vauban.clear_cache_for_user!(user)
```

**Disable Caching:**

```ruby
Vauban.configure do |config|
  config.cache_store = nil  # Disable caching
end
```

## Development

### Requirements

- Ruby >= 3.0.0, < 4.1 (Ruby 4.0+ may have compatibility issues with Rails 8.1)
- Rails >= 6.0

### Setup

After checking out the repo, run:

```bash
bundle install
```

### Testing

Vauban uses RSpec for testing. There are two types of tests:

1. **Unit tests** - Test core functionality without Rails
2. **Integration tests** - Test Rails integration with a dummy app

#### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run only unit tests (no Rails required)
bundle exec rspec spec/vauban/

# Run only integration tests (requires dummy app)
bundle exec rspec spec/integration/
```

#### Using the Dummy App

The dummy Rails app (`spec/dummy/`) is **included in the repo** as both:
- **Showcase**: See real examples of Vauban in action
- **Testing**: Used for integration tests

To use it:

```bash
cd spec/dummy
bundle install
rails db:create db:migrate db:seed
rails server
```

The dummy app includes:
- Example models (`User`, `Document`, `DocumentCollaboration`)
- Complete policy example (`DocumentPolicy`)
- All configured and ready to explore

See `spec/dummy/README.md` for more details.

## Documentation

- **[CONCEPTS.md](./CONCEPTS.md)** - Deep dive into ReBAC, authorization paradigms, and Vauban's design philosophy
- **[MIGRATION.md](./MIGRATION.md)** - Migration guides from CanCanCan and Pundit to Vauban
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Technical architecture and implementation details
- **[EXAMPLES.md](./EXAMPLES.md)** - Comprehensive code examples and use cases
- **[TESTING.md](./TESTING.md)** - Testing guide and best practices

## Roadmap / Future Improvements

This is an active project with planned improvements:

### High Priority
- [x] **Caching Implementation**: Implement caching for permission checks
  - ✅ Cache `Vauban.can?` results
  - ✅ Cache `Registry.policy_for` lookups
  - ✅ Optimize batch operations
- [x] **Better Error Messages**: More descriptive errors with helpful suggestions
  - ✅ Enhanced `PolicyNotFound` with expected policy class name, file location, and code examples
  - ✅ Enhanced `Unauthorized` with user info, available permissions, and debugging suggestions
  - ✅ Improved permission evaluation error logging with detailed context (permission, rule type, resource, user, backtrace)
  - ✅ Enhanced `ArgumentError` messages in Registry and Policy with actionable fixes
- [ ] **Performance Optimizations**: 
  - Prevent N+1 queries in batch permission checks
  - Improve lazy loading
  - Add memoization for policy instances

### Medium Priority
- [ ] **Developer Experience**: 
  - Debug mode with detailed logging
  - Policy validation (warn on common mistakes)
  - Enhanced generator templates
- [ ] **Documentation**: 
  - API documentation (YARD/RDoc)
  - Performance benchmarks
  - Migration checklist
- [ ] **Testing Utilities**: 
  - RSpec matchers (`expect(user).to be_able_to(:edit, document)`)
  - Test helpers for common scenarios
- [ ] **CI/CD Setup**: 
  - GitHub Actions workflow
  - Test against multiple Rails versions

### Nice to Have
- [ ] **Advanced Features**: 
  - Permission inheritance/composition
  - Conditional permissions based on resource state
  - Time-based permissions
- [ ] **Monitoring**: 
  - Metrics (permission check counts, cache hit rates)
  - Performance profiling hooks
- [ ] **Code Quality**: 
  - Security audit (bundler-audit)

## Contributing

Bug reports and pull requests are welcome! Please check the [roadmap](#roadmap--future-improvements) above for areas where contributions would be especially valuable.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
