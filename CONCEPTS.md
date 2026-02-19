# Vauban Concepts

## Table of Contents

1. [What is Relationship-Based Access Control (ReBAC)?](#what-is-relationship-based-access-control-rebac)
2. [Why ReBAC?](#why-rebac)
3. [Authorization Paradigms Comparison](#authorization-paradigms-comparison)
4. [How Vauban Implements ReBAC](#how-vauban-implements-rebac)
5. [Real-World Use Cases](#real-world-use-cases)
6. [Vauban vs Other Rails Authorization Gems](#vauban-vs-other-rails-authorization-gems)
7. [When to Use Vauban](#when-to-use-vauban)

---

## What is Relationship-Based Access Control (ReBAC)?

**Relationship-Based Access Control (ReBAC)** is an authorization paradigm that determines access permissions based on the **relationships** between entities in your system, rather than static roles or attributes.

### Core Principle

In ReBAC, authorization decisions are made by evaluating:
- **Who** the user is in relation to the resource
- **What relationships** exist between the user and the resource
- **How those relationships** grant or deny specific permissions

### Example: Document Collaboration

Consider a document collaboration system:

```ruby
# Traditional RBAC approach (role-based)
if user.role == :admin || user.role == :editor
  allow :edit
end

# ReBAC approach (relationship-based)
if document.owner == user || document.collaborators.include?(user)
  allow :edit
end
```

The ReBAC approach is more **expressive** and **flexible** because:
- It models real-world relationships (owner, collaborator, viewer)
- It adapts automatically as relationships change
- It doesn't require maintaining a separate role system
- It scales better for complex, multi-tenant applications

---

## Why ReBAC?

### 1. **Natural Modeling**

ReBAC mirrors how we think about permissions in real life:
- "Can Alice edit this document?" → "Is Alice the owner or a collaborator?"
- "Can Bob view this project?" → "Is Bob a member of the project's team?"
- "Can Charlie delete this comment?" → "Is Charlie the comment author or a moderator?"

### 2. **Dynamic and Contextual**

Relationships change over time, and ReBAC adapts automatically:
- A user becomes a collaborator → permissions update immediately
- A document is shared with a team → all team members gain access
- A user leaves a project → permissions are automatically revoked

### 3. **Scalable for Complex Systems**

As applications grow, role-based systems become unwieldy:
- **Role Explosion**: Need roles like `project_admin`, `project_member`, `project_viewer`, `project_guest`, etc.
- **Permission Inheritance**: Complex hierarchies become hard to maintain
- **Multi-Tenancy**: Difficult to model tenant-specific permissions

ReBAC scales naturally because relationships are **composable**:
```ruby
# Simple relationship check
document.owner == user

# Composed relationship check
document.team.members.include?(user) && 
document.team.organization.members.include?(user)
```

### 4. **Google Zanzibar Model**

ReBAC is inspired by **Google Zanzibar**, the authorization system used by Google for services like Drive, Calendar, and Cloud Platform. Zanzibar handles billions of authorization checks per second by modeling permissions as relationships in a graph.

Vauban brings this powerful paradigm to Rails applications.

---

## Authorization Paradigms Comparison

### Role-Based Access Control (RBAC)

**How it works**: Users are assigned roles, and roles have permissions.

```ruby
# Example with CanCanCan
class Ability
  can :edit, Document, user_id: user.id
  can :edit, Document if user.role == :admin
end
```

**Pros**:
- Simple to understand
- Good for hierarchical organizations
- Well-established pattern

**Cons**:
- Role explosion (admin, editor, viewer, guest, etc.)
- Hard to model complex relationships
- Static assignments don't adapt to context
- Difficult for multi-tenant applications

**Best for**: Simple applications with clear role hierarchies (e.g., admin/user, manager/employee).

---

### Attribute-Based Access Control (ABAC)

**How it works**: Permissions are based on attributes of users, resources, and environment.

```ruby
# Example
if user.department == resource.department && 
   user.security_clearance >= resource.classification &&
   Time.current.between?(9, 17)
  allow :access
end
```

**Pros**:
- Very flexible
- Can model complex policies
- Context-aware (time, location, etc.)

**Cons**:
- Complex to implement and maintain
- Performance challenges (many attribute checks)
- Hard to reason about (many conditions)

**Best for**: Systems requiring fine-grained, context-aware policies (e.g., government systems, healthcare).

---

### Policy-Based Access Control (PBAC)

**How it works**: Permissions are defined in external policy files (YAML, JSON, or DSL).

```ruby
# Example with Pundit
class DocumentPolicy
  def edit?
    user.admin? || record.owner == user
  end
end
```

**Pros**:
- Policies are separate from code
- Easy to test
- Can be versioned and audited

**Cons**:
- Still often role-based under the hood
- Can become procedural rather than declarative
- Policy files can become complex

**Best for**: Applications needing clear separation between policies and business logic.

---

### Relationship-Based Access Control (ReBAC)

**How it works**: Permissions are determined by relationships between entities.

```ruby
# Example with Vauban
class DocumentPolicy < Vauban::Policy
  permission :edit do
    allow_if { |doc, user| doc.owner == user }
    allow_if { |doc, user| doc.collaborators.include?(user) }
  end
end
```

**Pros**:
- Natural modeling of real-world relationships
- Composable and scalable
- Adapts automatically to relationship changes
- Excellent for multi-tenant applications
- Inspired by Google Zanzibar

**Cons**:
- Requires understanding relationship modeling
- May be overkill for simple applications

**Best for**: Modern applications with complex relationships, multi-tenancy, collaboration features, or social networks.

---

## How Vauban Implements ReBAC

### 1. **Policy-Based Architecture**

Vauban uses **policies** to define permissions for each resource type:

```ruby
class DocumentPolicy < Vauban::Policy
  resource Document
  
  permission :view do
    allow_if { |doc, user| doc.owner == user }
    allow_if { |doc, user| doc.collaborators.include?(user) }
    allow_if { |doc| doc.public? }
  end
end
```

Each policy:
- Defines **permissions** (actions like `:view`, `:edit`, `:delete`)
- Uses **rules** (`allow_if` blocks) that check relationships
- Is **declarative** and **readable**

### 2. **Relationship Evaluation**

Vauban evaluates relationships through:
- **Direct relationships**: `document.owner == user`
- **Indirect relationships**: `document.team.members.include?(user)`
- **Composed relationships**: Multiple conditions combined with `&&` or `||`
- **Reusable relationship definitions**: Using the `relationship` DSL method

**Basic Relationship Checks:**

```ruby
permission :edit do
  # Direct relationship
  allow_if { |doc, user| doc.owner == user }
  
  # Indirect relationship through collaboration
  allow_if { |doc, user| 
    doc.collaborators.include?(user) && 
    doc.collaboration_permissions(user).include?(:edit)
  }
  
  # Composed relationship
  allow_if { |doc, user|
    doc.team.members.include?(user) &&
    doc.team.organization.admins.include?(user)
  }
end
```

**Reusable Relationship Definitions:**

You can define relationships once and reuse them across permissions:

```ruby
class DocumentPolicy < Vauban::Policy
  resource Document

  # Define reusable relationships
  relationship :owner do
    owner
  end

  relationship :collaborator? do |user|
    collaborators.include?(user)
  end

  permission :view do
    # Use relationships in permission checks
    allow_if { |doc, user| evaluate_relationship(:owner, doc) == user }
    allow_if { |doc, user| evaluate_relationship(:collaborator?, doc, user) }
    allow_if { |doc| doc.public? }
  end

  permission :edit do
    allow_if { |doc, user| evaluate_relationship(:owner, doc) == user }
    allow_if { |doc, user| 
      evaluate_relationship(:collaborator?, doc, user) &&
      doc.collaboration_permissions(user).include?(:edit)
    }
  end
end
```

This approach makes relationships reusable and easier to maintain, especially when the same relationship logic is used across multiple permissions.

### 3. **Declarative DSL**

Vauban's DSL is designed to be **readable** and **maintainable**:

```ruby
# Clear and expressive
permission :delete do
  allow_if { |doc, user| doc.owner == user && !doc.archived? }
end
```

This reads like: "Allow delete if the user is the owner AND the document is not archived."

### 4. **Scoping for Performance**

Vauban supports **scopes** to efficiently query accessible resources:

```ruby
scope :view do |user|
  Document.where(public: true)
    .or(Document.where(owner: user))
    .or(Document.joins(:collaborators).where(collaborators: { user: user }))
end
```

This allows efficient database queries instead of checking each resource individually.

### 5. **Context-Aware Authorization**

Vauban supports **context** for time-sensitive or environment-aware permissions:

```ruby
permission :edit do
  allow_if { |doc, user, context|
    doc.owner == user &&
    context[:time].between?(9, 17) &&  # Business hours
    context[:ip_address].in?(user.allowed_ips)
  }
end
```

---

## Real-World Use Cases

### 1. **Document Collaboration (Google Docs, Notion)**

**Challenge**: Users can view/edit documents based on ownership and collaboration relationships.

**Vauban Solution**:
```ruby
class DocumentPolicy < Vauban::Policy
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
end
```

### 2. **Multi-Tenant SaaS (Slack, GitHub)**

**Challenge**: Users belong to organizations/teams, and permissions depend on membership.

**Vauban Solution**:
```ruby
class ProjectPolicy < Vauban::Policy
  permission :view do
    allow_if { |project, user| project.organization.members.include?(user) }
  end
  
  permission :admin do
    allow_if { |project, user| project.organization.owners.include?(user) }
    allow_if { |project, user| project.team.admins.include?(user) }
  end
end
```

### 3. **Social Networks (Facebook, LinkedIn)**

**Challenge**: Permissions based on friendship, group membership, and privacy settings.

**Vauban Solution**:
```ruby
class PostPolicy < Vauban::Policy
  permission :view do
    allow_if { |post, user| post.author == user }
    allow_if { |post, user| post.author.friends.include?(user) }
    allow_if { |post, user| post.group.members.include?(user) }
    allow_if { |post| post.public? }
  end
  
  permission :comment do
    allow_if { |post, user| can?(:view, post, user) }
    allow_if { |post, user| post.author.friends.include?(user) }
  end
end
```

### 4. **E-Commerce Marketplaces (Shopify, Etsy)**

**Challenge**: Sellers manage their stores, customers have purchase history, admins oversee everything.

**Vauban Solution**:
```ruby
class ProductPolicy < Vauban::Policy
  permission :edit do
    allow_if { |product, user| product.store.owner == user }
    allow_if { |product, user| product.store.staff.include?(user) }
  end
  
  permission :purchase do
    allow_if { |product, user| product.store.customers.include?(user) }
    allow_if { |product, user| product.public? }
  end
end
```

---

## Vauban vs Other Rails Authorization Gems

### Vauban vs Pundit

**Pundit**:
- Policy classes with methods (`def edit?`)
- Procedural (if/else logic)
- Often role-based under the hood
- Simple and lightweight

**Vauban**:
- Declarative DSL (`permission :edit do`)
- Relationship-based by design
- More expressive for complex scenarios
- Better for multi-tenant applications

**Choose Pundit if**: You need a simple, procedural approach with minimal learning curve.

**Choose Vauban if**: You have complex relationships, multi-tenancy, or want a more declarative approach.

---

### Vauban vs CanCanCan

**CanCanCan**:
- Centralized `Ability` class
- Role-based permissions
- Can become unwieldy for large applications
- Hard to test individual policies

**Vauban**:
- One policy per resource type
- Relationship-based permissions
- Scales better for complex applications
- Easy to test (each policy is isolated)

**Choose CanCanCan if**: You have simple role hierarchies and prefer centralized permissions.

**Choose Vauban if**: You have complex relationships or want better scalability.

---

### Vauban vs Action Policy

**Action Policy**:
- Similar to Pundit but with more features
- Supports scopes and rules
- Good testing support
- Still often role-based

**Vauban**:
- Relationship-first design
- More expressive DSL
- Built-in frontend API support
- Admin UI for exploration

**Choose Action Policy if**: You want Pundit-like syntax with more features.

**Choose Vauban if**: You want relationship-based authorization with modern tooling.

---

### Vauban vs Oso / SpiceDB (External Services)

**Oso / SpiceDB**:
- External authorization services
- Policy-as-code (Polar language)
- Requires separate service
- Good for microservices

**Vauban**:
- Embedded in Rails application
- Ruby DSL (no new language)
- No external dependencies
- Simpler deployment

**Choose Oso/SpiceDB if**: You need cross-service authorization or want policy-as-code.

**Choose Vauban if**: You want Rails-native authorization without external services.

---

## When to Use Vauban

### ✅ **Use Vauban When:**

1. **Complex Relationships**: Your application has rich relationships between users and resources (collaboration, teams, organizations, etc.)

2. **Multi-Tenancy**: You need to model permissions across multiple tenants/organizations

3. **Collaboration Features**: Users collaborate on resources (documents, projects, etc.)

4. **Social Features**: Your app has social elements (friends, groups, followers)

5. **Scalability Concerns**: You anticipate your authorization needs will grow complex

6. **Modern Architecture**: You're building a modern Rails app and want a forward-thinking authorization solution

### ❌ **Don't Use Vauban When:**

1. **Simple Role Hierarchy**: You only need basic roles (admin/user, manager/employee)

2. **Minimal Relationships**: Your permissions don't depend on relationships

3. **Learning Curve Concerns**: Your team prefers simpler, more established patterns

4. **External Authorization**: You need cross-service authorization (use Oso/SpiceDB instead)

---

## Summary

**Vauban** brings **Relationship-Based Access Control (ReBAC)** to Rails, inspired by Google Zanzibar. It's designed for modern applications with complex relationships, multi-tenancy, and collaboration features.

**Key Benefits**:
- 🎯 **Natural Modeling**: Permissions mirror real-world relationships
- 🔄 **Dynamic**: Adapts automatically as relationships change
- 📈 **Scalable**: Composable relationships scale to complex scenarios
- 🛠️ **Developer-Friendly**: Readable DSL, great tooling, easy testing
- 🚀 **Modern**: Built for today's Rails applications

**When to Choose Vauban**: When your authorization needs go beyond simple roles and require modeling complex relationships between users and resources.

---

## Further Reading

- [Google Zanzibar Paper](https://research.google/pubs/zanzibar-googles-consistent-global-authorization-system/)
- [Vauban Architecture](./ARCHITECTURE.md)
- [Vauban Examples](./EXAMPLES.md)
- [Vauban Testing Guide](./TESTING.md)
