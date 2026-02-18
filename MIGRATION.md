# Migration Guide

This guide helps you migrate from **CanCanCan** or **Pundit** to **Vauban**. Both migrations follow similar patterns but have some key differences.

## Table of Contents

1. [Migration from CanCanCan](#migration-from-cancancan)
2. [Migration from Pundit](#migration-from-pundit)
3. [Common Patterns](#common-patterns)
4. [Step-by-Step Migration Process](#step-by-step-migration-process)
5. [Gotchas and Differences](#gotchas-and-differences)

---

## Migration from CanCanCan

### Overview

**CanCanCan** uses a centralized `Ability` class with `can`/`cannot` methods. **Vauban** uses separate policy classes for each resource type with a declarative DSL.

### Key Differences

| CanCanCan | Vauban |
|-----------|---------|
| Single `Ability` class | One `Policy` class per resource |
| `can :action, Model` | `permission :action do` |
| `can :read, Document, user_id: user.id` | `allow_if { \|doc, user\| doc.user == user }` |
| `load_and_authorize_resource` | Manual `authorize!` calls |
| `accessible_by(current_ability)` | `Vauban.accessible_by(user, :action, Model)` |

---

### 1. Ability Class → Policy Classes

#### Before (CanCanCan)

```ruby
# app/models/ability.rb
class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # guest user

    if user.admin?
      can :manage, :all
    else
      can :read, Document, public: true
      can :read, Document, user_id: user.id
      can :update, Document, user_id: user.id
      can :destroy, Document, user_id: user.id
    end
  end
end
```

#### After (Vauban)

```ruby
# app/policies/document_policy.rb
class DocumentPolicy < Vauban::Policy
  resource Document

  permission :read do
    allow_if { |doc, user| user&.admin? }  # Admin can read all
    allow_if { |doc| doc.public? }
    allow_if { |doc, user| doc.user == user }
  end

  permission :update do
    allow_if { |doc, user| user&.admin? }
    allow_if { |doc, user| doc.user == user }
  end

  permission :destroy do
    allow_if { |doc, user| user&.admin? }
    allow_if { |doc, user| doc.user == user }
  end
end
```

**Key Changes**:
- Split one `Ability` class into multiple policy classes
- Convert `can :action` to `permission :action do`
- Convert hash conditions to relationship checks in `allow_if` blocks

---

### 2. Controller Authorization

#### Before (CanCanCan)

```ruby
class DocumentsController < ApplicationController
  load_and_authorize_resource

  def index
    # @documents is automatically loaded and scoped
  end

  def show
    # @document is automatically loaded and authorized
  end

  def update
    # @document is automatically loaded and authorized
    @document.update(document_params)
  end
end
```

#### After (Vauban)

```ruby
class DocumentsController < ApplicationController
  include Vauban::Rails::ControllerHelpers

  def index
    @documents = Vauban.accessible_by(current_user, :read, Document)
  end

  def show
    @document = Document.find(params[:id])
    authorize! :read, @document
  end

  def update
    @document = Document.find(params[:id])
    authorize! :update, @document
    @document.update(document_params)
  end
end
```

**Key Changes**:
- Remove `load_and_authorize_resource`
- Include `Vauban::Rails::ControllerHelpers`
- Manually load resources with `find`
- Call `authorize!` explicitly
- Use `Vauban.accessible_by` for scoped queries

---

### 3. View Helpers

#### Before (CanCanCan)

```erb
<% if can?(:update, @document) %>
  <%= link_to "Edit", edit_document_path(@document) %>
<% end %>

<% if cannot?(:destroy, @document) %>
  <p>You cannot delete this document</p>
<% end %>
```

#### After (Vauban)

```erb
<% if can?(:update, @document) %>
  <%= link_to "Edit", edit_document_path(@document) %>
<% end %>

<% if cannot?(:destroy, @document) %>
  <p>You cannot delete this document</p>
<% end %>
```

**Key Changes**: 
- View helpers (`can?`, `cannot?`) work the same! ✅

---

### 4. Scoping (accessible_by)

#### Before (CanCanCan)

```ruby
# In controller
@documents = Document.accessible_by(current_ability)

# With conditions
@documents = Document.accessible_by(current_ability, :read)
```

#### After (Vauban)

```ruby
# In controller
@documents = Vauban.accessible_by(current_user, :read, Document)

# Or use scopes defined in policy
class DocumentPolicy < Vauban::Policy
  scope :read do |user|
    Document.where(public: true)
      .or(Document.where(user: user))
  end
end

# Then in controller
policy = DocumentPolicy.new(current_user)
@documents = policy.scope(current_user, :read)
```

**Key Changes**:
- Replace `accessible_by(current_ability)` with `Vauban.accessible_by(user, :action, Model)`
- Define scopes in policy classes for better performance

---

### 5. Complex Conditions

#### Before (CanCanCan)

```ruby
class Ability
  def initialize(user)
    can :read, Document do |document|
      document.public? || 
      document.user == user || 
      document.collaborators.include?(user)
    end

    can :update, Document, user_id: user.id, archived: false
  end
end
```

#### After (Vauban)

```ruby
class DocumentPolicy < Vauban::Policy
  resource Document

  permission :read do
    allow_if { |doc| doc.public? }
    allow_if { |doc, user| doc.user == user }
    allow_if { |doc, user| doc.collaborators.include?(user) }
  end

  permission :update do
    allow_if { |doc, user| doc.user == user && !doc.archived? }
  end
end
```

**Key Changes**:
- Convert block conditions to `allow_if` blocks
- Convert hash conditions to relationship checks
- Multiple `allow_if` blocks are OR'd together

---

### 6. Role-Based Permissions

#### Before (CanCanCan)

```ruby
class Ability
  def initialize(user)
    case user.role
    when :admin
      can :manage, :all
    when :moderator
      can :read, :all
      can :update, Post
      can :destroy, Post, user_id: user.id
    when :user
      can :read, Post, public: true
      can :create, Post
      can :update, Post, user_id: user.id
    end
  end
end
```

#### After (Vauban)

```ruby
class PostPolicy < Vauban::Policy
  resource Post

  permission :read do
    allow_if { |post, user| user&.admin? || user&.moderator? }
    allow_if { |post| post.public? }
    allow_if { |post, user| post.user == user }
  end

  permission :create do
    allow_if { |post, user| user&.admin? || user&.moderator? || user&.user? }
  end

  permission :update do
    allow_if { |post, user| user&.admin? }
    allow_if { |post, user| user&.moderator? }
    allow_if { |post, user| user&.user? && post.user == user }
  end

  permission :destroy do
    allow_if { |post, user| user&.admin? }
    allow_if { |post, user| user&.moderator? && post.user == user }
  end
end
```

**Key Changes**:
- Role checks become relationship checks (`user.admin?`, `user.moderator?`)
- Vauban encourages relationship-based permissions, but supports role checks

---

## Migration from Pundit

### Overview

**Pundit** uses policy classes with methods (`def edit?`). **Vauban** uses policy classes with a declarative DSL (`permission :edit do`). The structure is similar, making migration easier.

### Key Differences

| Pundit | Vauban |
|--------|---------|
| `def edit?` methods | `permission :edit do` blocks |
| `authorize @document` | `authorize! :edit, @document` |
| `policy_scope(Document)` | `Vauban.accessible_by(user, :read, Document)` |
| `@user` instance variable | `user` parameter in blocks |

---

### 1. Policy Classes

#### Before (Pundit)

```ruby
# app/policies/document_policy.rb
class DocumentPolicy
  attr_reader :user, :document

  def initialize(user, document)
    @user = user
    @document = document
  end

  def show?
    document.public? || document.user == user || user.admin?
  end

  def edit?
    document.user == user || user.admin?
  end

  def destroy?
    document.user == user && !document.archived? && user.admin?
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.where(public: true)
        .or(scope.where(user: user))
    end
  end
end
```

#### After (Vauban)

```ruby
# app/policies/document_policy.rb
class DocumentPolicy < Vauban::Policy
  resource Document

  permission :show do
    allow_if { |doc| doc.public? }
    allow_if { |doc, user| doc.user == user }
    allow_if { |doc, user| user&.admin? }
  end

  permission :edit do
    allow_if { |doc, user| doc.user == user }
    allow_if { |doc, user| user&.admin? }
  end

  permission :destroy do
    allow_if { |doc, user| doc.user == user && !doc.archived? && user&.admin? }
  end

  scope :show do |user|
    Document.where(public: true)
      .or(Document.where(user: user))
  end
end
```

**Key Changes**:
- Remove `initialize` method (Vauban handles this)
- Convert `def action?` methods to `permission :action do` blocks
- Convert `Scope` class to `scope :action do` blocks
- Use `allow_if` blocks instead of returning boolean

---

### 2. Controller Authorization

#### Before (Pundit)

```ruby
class DocumentsController < ApplicationController
  include Pundit::Authorization

  def index
    @documents = policy_scope(Document)
  end

  def show
    @document = Document.find(params[:id])
    authorize @document
  end

  def update
    @document = Document.find(params[:id])
    authorize @document
    @document.update(document_params)
  end

  def destroy
    @document = Document.find(params[:id])
    authorize @document, :destroy?
    @document.destroy
  end
end
```

#### After (Vauban)

```ruby
class DocumentsController < ApplicationController
  include Vauban::Rails::ControllerHelpers

  def index
    @documents = Vauban.accessible_by(current_user, :show, Document)
  end

  def show
    @document = Document.find(params[:id])
    authorize! :show, @document
  end

  def update
    @document = Document.find(params[:id])
    authorize! :update, @document
    @document.update(document_params)
  end

  def destroy
    @document = Document.find(params[:id])
    authorize! :destroy, @document
    @document.destroy
  end
end
```

**Key Changes**:
- Replace `include Pundit::Authorization` with `include Vauban::Rails::ControllerHelpers`
- Replace `authorize @document` with `authorize! :action, @document` (explicit action)
- Replace `policy_scope(Document)` with `Vauban.accessible_by(user, :action, Document)`

---

### 3. View Helpers

#### Before (Pundit)

```erb
<% if policy(@document).edit? %>
  <%= link_to "Edit", edit_document_path(@document) %>
<% end %>

<% if policy(@document).destroy? %>
  <%= link_to "Delete", document_path(@document), method: :delete %>
<% end %>
```

#### After (Vauban)

```erb
<% if can?(:edit, @document) %>
  <%= link_to "Edit", edit_document_path(@document) %>
<% end %>

<% if can?(:destroy, @document) %>
  <%= link_to "Delete", document_path(@document), method: :delete %>
<% end %>
```

**Key Changes**:
- Replace `policy(@document).action?` with `can?(:action, @document)`
- Simpler, more consistent API

---

### 4. Scoping (policy_scope)

#### Before (Pundit)

```ruby
# In controller
@documents = policy_scope(Document)

# Custom scope
@documents = policy_scope(Document).where(archived: false)
```

#### After (Vauban)

```ruby
# In controller
@documents = Vauban.accessible_by(current_user, :show, Document)

# Or use scopes defined in policy
class DocumentPolicy < Vauban::Policy
  scope :show do |user|
    Document.where(public: true)
      .or(Document.where(user: user))
  end
end

# Then chain ActiveRecord methods
@documents = Vauban.accessible_by(current_user, :show, Document)
  .where(archived: false)
```

**Key Changes**:
- Replace `policy_scope(Model)` with `Vauban.accessible_by(user, :action, Model)`
- Define scopes in policy classes

---

### 5. Complex Conditions

#### Before (Pundit)

```ruby
class DocumentPolicy
  def edit?
    return true if user.admin?
    return false unless document.user == user
    
    document.collaborators.include?(user) && 
    document.collaboration_permissions(user).include?(:edit)
  end
end
```

#### After (Vauban)

```ruby
class DocumentPolicy < Vauban::Policy
  resource Document

  permission :edit do
    allow_if { |doc, user| user&.admin? }
    allow_if { |doc, user| 
      doc.user == user && 
      doc.collaborators.include?(user) && 
      doc.collaboration_permissions(user).include?(:edit)
    }
  end
end
```

**Key Changes**:
- Convert early returns to separate `allow_if` blocks
- Each `allow_if` block is evaluated independently (OR logic)

---

### 6. Multiple Actions

#### Before (Pundit)

```ruby
class DocumentPolicy
  def show?
    document.public? || document.user == user
  end

  def edit?
    document.user == user
  end

  def destroy?
    document.user == user && !document.archived?
  end
end
```

#### After (Vauban)

```ruby
class DocumentPolicy < Vauban::Policy
  resource Document

  permission :show do
    allow_if { |doc| doc.public? }
    allow_if { |doc, user| doc.user == user }
  end

  permission :edit do
    allow_if { |doc, user| doc.user == user }
  end

  permission :destroy do
    allow_if { |doc, user| doc.user == user && !doc.archived? }
  end
end
```

**Key Changes**:
- Each action becomes a `permission` block
- More declarative and readable

---

## Common Patterns

### 1. Guest Users

#### CanCanCan

```ruby
class Ability
  def initialize(user)
    user ||= User.new # guest user
    can :read, Document, public: true
  end
end
```

#### Pundit

```ruby
class DocumentPolicy
  def initialize(user, document)
    @user = user || User.new
    @document = document
  end

  def show?
    document.public? || document.user == user
  end
end
```

#### Vauban

```ruby
class DocumentPolicy < Vauban::Policy
  resource Document

  permission :show do
    allow_if { |doc| doc.public? }
    allow_if { |doc, user| doc.user == user if user }
  end
end
```

**Key**: Use `if user` or `user&.` to handle nil users safely.

---

### 2. Admin Override

#### CanCanCan / Pundit

```ruby
# In policy/ability
if user.admin?
  return true  # Admin can do everything
end
```

#### Vauban

```ruby
class DocumentPolicy < Vauban::Policy
  resource Document

  permission :edit do
    allow_if { |doc, user| user&.admin? }  # Admin override first
    allow_if { |doc, user| doc.user == user }
  end
end
```

**Key**: Put admin checks first in `allow_if` blocks for early return.

---

### 3. Conditional Permissions

#### CanCanCan

```ruby
can :update, Document, user_id: user.id, archived: false
```

#### Pundit

```ruby
def update?
  document.user == user && !document.archived?
end
```

#### Vauban

```ruby
permission :update do
  allow_if { |doc, user| doc.user == user && !doc.archived? }
end
```

**Key**: Combine conditions with `&&` in a single `allow_if` block.

---

### 4. Relationship-Based Permissions

#### CanCanCan

```ruby
can :read, Document do |document|
  document.user == user || 
  document.collaborators.include?(user) ||
  document.team.members.include?(user)
end
```

#### Pundit

```ruby
def show?
  document.user == user || 
  document.collaborators.include?(user) ||
  document.team.members.include?(user)
end
```

#### Vauban

```ruby
permission :show do
  allow_if { |doc, user| doc.user == user }
  allow_if { |doc, user| doc.collaborators.include?(user) }
  allow_if { |doc, user| doc.team.members.include?(user) }
end
```

**Key**: Vauban excels at relationship-based permissions! Each relationship becomes a separate `allow_if` block.

---

## Step-by-Step Migration Process

### Phase 1: Setup

1. **Add Vauban to Gemfile**
   ```ruby
   gem 'vauban'
   ```

2. **Run installer**
   ```bash
   rails generate vauban:install
   ```

3. **Configure Vauban**
   ```ruby
   # config/initializers/vauban.rb
   Vauban.configure do |config|
     config.current_user_method = :current_user
   end
   ```

### Phase 2: Create Policies (One Resource at a Time)

1. **Generate policy for first resource**
   ```bash
   rails generate vauban:policy Document
   ```

2. **Migrate permissions from CanCanCan/Pundit**
   - Convert `can` statements or `def action?` methods to `permission :action do` blocks
   - Convert conditions to `allow_if` blocks

3. **Test the policy**
   ```ruby
   # In Rails console
   user = User.first
   doc = Document.first
   Vauban.can?(user, :show, doc)
   ```

### Phase 3: Update Controllers

1. **Include Vauban helpers**
   ```ruby
   include Vauban::Rails::ControllerHelpers
   ```

2. **Replace authorization calls**
   - CanCanCan: Remove `load_and_authorize_resource`, add `authorize!`
   - Pundit: Replace `authorize @resource` with `authorize! :action, @resource`

3. **Update scoping**
   - CanCanCan: Replace `accessible_by(current_ability)` with `Vauban.accessible_by(user, :action, Model)`
   - Pundit: Replace `policy_scope(Model)` with `Vauban.accessible_by(user, :action, Model)`

### Phase 4: Update Views

1. **Replace view helpers**
   - CanCanCan: `can?` works the same ✅
   - Pundit: Replace `policy(@resource).action?` with `can?(:action, @resource)`

### Phase 5: Remove Old Gem

1. **Remove from Gemfile**
   ```ruby
   # gem 'cancancan'  # Remove this
   # gem 'pundit'    # Remove this
   ```

2. **Remove old code**
   - Delete `app/models/ability.rb` (CanCanCan)
   - Delete old policy files if migrating from Pundit (or keep temporarily)

3. **Run tests**
   ```bash
   bundle exec rspec
   ```

---

## Gotchas and Differences

### 1. **Action Names**

- **CanCanCan**: Uses `:read`, `:update`, `:destroy` (RESTful)
- **Pundit**: Uses `show?`, `edit?`, `destroy?` (controller actions)
- **Vauban**: You choose! Use `:show`, `:edit`, `:destroy` or `:read`, `:update`, `:delete`

**Recommendation**: Use RESTful names (`:read`, `:update`, `:destroy`) for consistency.

---

### 2. **Default Deny**

- **CanCanCan**: Default deny (must explicitly allow)
- **Pundit**: Default deny (must return `true`)
- **Vauban**: Default deny (must have `allow_if` that returns `true`)

**All three work the same way** ✅

---

### 3. **Exception Handling**

- **CanCanCan**: Raises `CanCan::AccessDenied`
- **Pundit**: Raises `Pundit::NotAuthorizedError`
- **Vauban**: Raises `Vauban::Unauthorized`

**Update your rescue blocks**:
```ruby
# Before (CanCanCan)
rescue_from CanCan::AccessDenied do |exception|
  redirect_to root_url, alert: exception.message
end

# After (Vauban)
rescue_from Vauban::Unauthorized do |exception|
  redirect_to root_url, alert: exception.message
end
```

---

### 4. **Scoping Performance**

- **CanCanCan**: `accessible_by` can be slow for complex conditions
- **Pundit**: `policy_scope` requires manual `Scope` class
- **Vauban**: Define `scope` blocks in policies for better performance

**Example**:
```ruby
class DocumentPolicy < Vauban::Policy
  scope :show do |user|
    Document.where(public: true)
      .or(Document.where(user: user))
      .or(Document.joins(:collaborators).where(collaborators: { user: user }))
  end
end
```

---

### 5. **Testing**

#### CanCanCan

```ruby
# spec/models/ability_spec.rb
it "allows user to read own documents" do
  ability = Ability.new(user)
  expect(ability).to be_able_to(:read, document)
end
```

#### Pundit

```ruby
# spec/policies/document_policy_spec.rb
it "allows user to read own documents" do
  policy = DocumentPolicy.new(user, document)
  expect(policy.show?).to be true
end
```

#### Vauban

```ruby
# spec/policies/document_policy_spec.rb
it "allows user to read own documents" do
  expect(Vauban.can?(user, :show, document)).to be true
end

# Or test policy directly
it "allows user to read own documents" do
  policy = DocumentPolicy.new(user)
  expect(policy.allowed?(:show, document, user)).to be true
end
```

---

### 6. **Batch Operations**

- **CanCanCan**: No built-in batch support
- **Pundit**: No built-in batch support
- **Vauban**: Built-in `batch_permissions` for efficient checks

**Example**:
```ruby
# Check multiple resources at once
resources = [doc1, doc2, doc3]
permissions = Vauban.batch_permissions(current_user, resources)
# => { doc1 => {"show" => true, "edit" => false}, ... }
```

---

## Summary

### CanCanCan → Vauban

| Task | Change |
|------|--------|
| Ability class | → Policy classes (one per resource) |
| `can :action, Model` | → `permission :action do` |
| `load_and_authorize_resource` | → Manual `authorize!` calls |
| `accessible_by(current_ability)` | → `Vauban.accessible_by(user, :action, Model)` |
| View helpers | → Same (`can?`, `cannot?`) ✅ |

### Pundit → Vauban

| Task | Change |
|------|--------|
| `def action?` methods | → `permission :action do` blocks |
| `authorize @resource` | → `authorize! :action, @resource` |
| `policy_scope(Model)` | → `Vauban.accessible_by(user, :action, Model)` |
| `policy(@resource).action?` | → `can?(:action, @resource)` |
| `Scope` class | → `scope :action do` blocks |

---

## Need Help?

- Check [CONCEPTS.md](./CONCEPTS.md) for deep dive into ReBAC
- Check [EXAMPLES.md](./EXAMPLES.md) for more code examples
- Check [ARCHITECTURE.md](./ARCHITECTURE.md) for technical details
