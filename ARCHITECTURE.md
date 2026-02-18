# Vauban Architecture

## Overview

Vauban is a relationship-based authorization gem for Rails applications. It provides a clean DSL for defining authorization policies, efficient permission checking, and frontend API support.

## Core Components

### 1. Policy System (`lib/vauban/policy.rb`)

The heart of Vauban. Policies define what actions users can perform on resources.

- **Policy Class**: Base class for all policies
- **Permission**: Defines an action (view, edit, delete, etc.)
- **Rules**: `allow_if` and `deny_if` blocks that determine access

### 2. Registry (`lib/vauban/registry.rb`)

Manages policy discovery and registration.

- Auto-discovers policies from configured paths
- Maps resource classes to policy classes
- Supports package-aware organization (Packwerk)

### 3. Permission Evaluator (`lib/vauban/permission.rb`)

Evaluates permission rules.

- Processes `allow_if` and `deny_if` rules
- Returns boolean result
- Handles errors gracefully

### 4. Rails Integration (`lib/vauban/rails/`)

Provides Rails-specific helpers.

- **ControllerHelpers**: `authorize!`, `can?`, `cannot?` methods
- **ViewHelpers**: Same methods for views
- **Railtie**: Auto-configuration on Rails boot

### 5. API Support (`lib/vauban/api/`)

Frontend integration support.

- **PermissionsController**: Template for API endpoints
- Schema endpoint: Lists available permissions
- Check endpoint: Batch permission checking

### 6. Configuration (`lib/vauban/configuration.rb`)

Centralized configuration.

- Current user method
- Cache settings
- Policy discovery paths
- Frontend API settings

## Data Flow

```
User Request
    ↓
Controller calls authorize!(:action, resource)
    ↓
Vauban.authorize(user, :action, resource)
    ↓
Registry.policy_for(resource.class)
    ↓
Policy.allowed?(:action, resource, user)
    ↓
Permission.allowed?(resource, user)
    ↓
Evaluate allow_if/deny_if rules
    ↓
Return true/false
```

## File Structure

```
vauban/
├── lib/
│   ├── vauban.rb                    # Main entry point
│   ├── vauban/
│   │   ├── version.rb
│   │   ├── configuration.rb          # Configuration management
│   │   ├── policy.rb                 # Policy base class
│   │   ├── permission.rb             # Permission evaluator
│   │   ├── registry.rb               # Policy registry
│   │   ├── relationship.rb           # Relationship definitions
│   │   ├── core.rb                   # Core functionality
│   │   ├── railtie.rb                # Rails integration
│   │   ├── rails/
│   │   │   ├── controller_helpers.rb
│   │   │   └── view_helpers.rb
│   │   └── api/
│   │       └── permissions_controller.rb
│   └── generators/
│       └── vauban/
│           ├── install_generator.rb
│           └── policy_generator.rb
├── spec/                              # Tests
├── vauban.gemspec                    # Gem specification
├── Gemfile
├── README.md
└── EXAMPLES.md
```

## Key Design Decisions

### 1. Relationship-Based

Unlike CanCanCan/Pundit which focus on roles, Vauban emphasizes relationships. This makes it easier to model complex authorization scenarios.

### 2. Policy as Class

Each resource type has its own policy class, making it easy to organize and test.

### 3. Declarative DSL

Policies use a readable DSL that's easy to understand and maintain.

### 4. Package-Aware

Built for modular monoliths with Packwerk support.

### 5. Frontend-First

Includes API support for frontend permission checking.

## Extension Points

### Custom Permission Evaluators

You can extend `Vauban::Permission` to add custom evaluation logic.

### Custom Relationship Types

Extend `Vauban::Relationship` to define custom relationship types.

### Policy Mixins

Policies can include modules to share common logic:

```ruby
module ShareablePolicy
  def self.included(base)
    base.class_eval do
      permission :share do
        allow_if { |resource, user| resource.owner == user }
      end
    end
  end
end
```

## Performance Considerations

1. **Caching**: Configure cache store for permission results
2. **Batch Operations**: Use `batch_permissions` for multiple checks
3. **Scoping**: Define scopes to avoid N+1 queries
4. **Lazy Loading**: Policies are loaded on-demand

## Future Enhancements

- [ ] YAML/JSON policy DSL
- [ ] Policy visualization tool
- [ ] Permission explorer CLI
- [ ] Audit logging
- [ ] Performance monitoring
- [ ] Policy testing framework
- [ ] GraphQL integration helpers
