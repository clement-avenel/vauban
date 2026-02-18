# Vauban Examples

## Basic Policy Definition

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

  # Scoping for efficient queries
  scope :view do |user|
    Document.where(public: true)
      .or(Document.where(owner: user))
      .or(Document.joins(:collaborators).where(collaborators: { user: user }))
  end
end
```

## Controller Usage

```ruby
class DocumentsController < ApplicationController
  def index
    @documents = Vauban.accessible_by(current_user, :view, Document)
  end

  def show
    @document = Document.find(params[:id])
    authorize! :view, @document
  end

  def update
    @document = Document.find(params[:id])
    authorize! :edit, @document
    # ... update logic
  end

  def destroy
    @document = Document.find(params[:id])
    authorize! :delete, @document
    # ... delete logic
  end
end
```

## View Usage

```erb
<% if can?(:edit, @document) %>
  <%= link_to "Edit", edit_document_path(@document) %>
<% end %>

<% if can?(:delete, @document) %>
  <%= link_to "Delete", document_path(@document), method: :delete, 
      data: { confirm: "Are you sure?" } %>
<% end %>
```

## Frontend API

### Controller Setup

```ruby
# app/controllers/api/v1/permissions_controller.rb
class Api::V1::PermissionsController < Api::BaseController
  include Vauban::Api::PermissionsController

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

  def schema
    render json: {
      resources: Vauban::Registry.resources.map do |resource_class|
        policy = Vauban::Registry.policy_for(resource_class)
        next unless policy

        {
          type: resource_class.name,
          permissions: policy.available_permissions.map(&:to_s)
        }
      end.compact
    }
  end

  private

  def find_resource(resource_param)
    if resource_param.is_a?(String)
      type, id = resource_param.split(":")
      type.constantize.find(id)
    elsif resource_param.is_a?(Hash)
      resource_param[:type].constantize.find(resource_param[:id])
    else
      resource_param
    end
  end
end
```

### Routes

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    get 'permissions/schema', to: 'permissions#schema'
    post 'permissions/check', to: 'permissions#check'
  end
end
```

## Context-Aware Authorization

```ruby
class DocumentPolicy < Vauban::Policy
  resource Document

  permission :edit do
    allow_if { |doc, user, context| 
      doc.owner == user &&
      context[:time].between?(9, 17) &&  # Business hours
      context[:ip_address].in?(user.allowed_ips)
    }
  end
end

# Usage
authorize! :edit, @document, context: {
  time: Time.current.hour,
  ip_address: request.remote_ip
}
```

## Package-Aware Policies (Packwerk)

```ruby
# packs/billing/app/policies/billing/invoice_policy.rb
module Billing
  class InvoicePolicy < Vauban::Policy
    resource Invoice
    package :billing

    permission :view do
      allow_if { |invoice, user| invoice.account.owner == user }
      allow_if { |invoice, user| invoice.account.members.include?(user) }
    end

    permission :edit do
      allow_if { |invoice, user| invoice.account.owner == user }
      allow_if { |invoice, user| 
        invoice.account.admins.include?(user) && 
        !invoice.paid?
      }
    end
  end
end

# Register in initializer
Vauban::Registry.register(Billing::InvoicePolicy, package: :billing)
```

## Batch Permission Checks

```ruby
# Check multiple resources at once
resources = [doc1, doc2, doc3]
permissions = Vauban.batch_permissions(current_user, resources)

permissions.each do |resource, perms|
  puts "#{resource.title}: view=#{perms['view']}, edit=#{perms['edit']}"
end
```

## Direct Usage (Outside Rails)

```ruby
user = User.find(1)
document = Document.find(1)

# Check permission
if Vauban.can?(user, :view, document)
  puts "User can view document"
end

# Authorize (raises if denied)
begin
  Vauban.authorize(user, :edit, document)
  # User can edit
rescue Vauban::Unauthorized
  # User cannot edit
end

# Get all permissions
perms = Vauban.all_permissions(user, document)
# => { "view" => true, "edit" => true, "delete" => false }
```
