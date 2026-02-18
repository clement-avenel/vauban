# frozen_string_literal: true

class User < ApplicationRecord
  has_many :documents, class_name: "Document", foreign_key: "owner_id", dependent: :destroy
  has_many :document_collaborations, class_name: "DocumentCollaboration", foreign_key: "user_id", dependent: :destroy
  has_many :collaborated_documents, through: :document_collaborations, source: :document
end
