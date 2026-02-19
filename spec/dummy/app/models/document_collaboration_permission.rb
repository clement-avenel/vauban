# frozen_string_literal: true

class DocumentCollaborationPermission < ApplicationRecord
  belongs_to :document_collaboration
  
  validates :permission, presence: true
  validates :permission, uniqueness: { scope: :document_collaboration_id }
end
