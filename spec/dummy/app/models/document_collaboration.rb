# frozen_string_literal: true

class DocumentCollaboration < ApplicationRecord
  extend Vauban::Grants

  belongs_to :document
  belongs_to :user
  has_many :document_collaboration_permissions, dependent: :destroy

  grants_relation :viewer, :editor, to: :user, on: :document do |record|
    perms = record.permissions
    rels = []
    rels << :viewer if perms.any?
    rels << :editor if perms.include?(:edit)
    rels
  end

  def permissions
    document_collaboration_permissions.pluck(:permission).map(&:to_sym)
  end
end
