# frozen_string_literal: true

class DocumentCollaboration < ApplicationRecord
  belongs_to :document
  belongs_to :user
  has_many :document_collaboration_permissions, dependent: :destroy
  
  # Convenience method to get permissions as an array of symbols
  def permissions
    document_collaboration_permissions.pluck(:permission).map(&:to_sym)
  end
end

