# Testing Guide

This guide explains how to test the Vauban gem.

## Quick Start

**Important:** Always run tests from the **root of the gem**, not from `spec/dummy/`.

```bash
# 1. Install gem dependencies (from gem root)
bundle install

# 2. Install dummy app dependencies (required for integration tests)
cd spec/dummy
bundle install
rails db:create db:migrate
cd ../..

# 3. Run unit tests (no Rails needed)
bundle exec rspec spec/vauban/

# 4. Run integration tests (requires dummy app and its dependencies)
bundle exec rspec spec/integration/

# 5. Run all tests
bundle exec rspec
```

**Note:** The dummy app has its own Gemfile and needs its dependencies installed separately. This is normal for Rails gems with dummy apps.

## Test Structure

### Unit Tests (`spec/vauban/`)

These tests don't require Rails and test core functionality:
- Policy definition and evaluation
- Permission rules
- Registry functionality
- Core authorization logic

**Run with:**
```bash
bundle exec rspec spec/vauban/
# or
bundle exec rake spec_unit
```

### Integration Tests (`spec/integration/`)

These tests require a Rails app and test:
- Rails controller/view helpers
- Full-stack authorization flow
- Generators

**Run with:**
```bash
bundle exec rspec spec/integration/
# or
bundle exec rake spec_integration
```

## Dummy App

The dummy Rails app (`spec/dummy/`) is **included in the repo** as both a showcase and testing environment.

### Quick Start

```bash
cd spec/dummy
bundle install
rails db:create db:migrate
rails server
```

Visit `http://localhost:3000` to see Vauban in action!

### What's Included

The dummy app is a complete example showing:
- **Models**: `User`, `Document`, `DocumentCollaboration` with relationships
- **Policy**: `DocumentPolicy` demonstrating relationship-based permissions
- **Configuration**: Complete setup example

See `spec/dummy/README.md` for detailed documentation.

### Manual Testing

You can also manually test the gem in the dummy app:

```bash
cd spec/dummy
rails console

# In console:
user = User.create!(email: "test@example.com", name: "Test")
doc = Document.create!(title: "Test", owner: user)
Vauban.can?(user, :view, doc)  # => true
```

## Writing Tests

### Unit Test Example

```ruby
# spec/vauban/policy_spec.rb
require "spec_helper"

RSpec.describe Vauban::Policy do
  let(:user) { double("User", id: 1) }
  
  # Your tests here
end
```

### Integration Test Example

```ruby
# spec/integration/rails_integration_spec.rb
require "rails_helper"

RSpec.describe "Vauban Rails Integration", type: :request do
  before do
    DummyAppSetup.setup_all
  end
  
  # Your tests here
end
```

## Troubleshooting

### "Dummy app not found"

The dummy app is included in the repository at `spec/dummy/`. If it's missing, check out the repository or restore it from git.

### "Rails environment is loading!"

Make sure you're running tests in test environment. Check `spec/rails_helper.rb`.

### Database errors

Make sure you've run migrations in the dummy app:
```bash
cd spec/dummy && rails db:migrate
```

### Missing models/policies

The `DummyAppSetup` helper automatically creates test models and policies. Make sure you call `DummyAppSetup.setup_all` in your integration tests.
