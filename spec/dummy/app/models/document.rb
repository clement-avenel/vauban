# frozen_string_literal: true

class Document < ApplicationRecord
  belongs_to :owner, class_name: "User", foreign_key: "owner_id"
  has_many :document_collaborations, class_name: "DocumentCollaboration", dependent: :destroy
  has_many :collaborators, through: :document_collaborations, source: :user

  validates :title, presence: true
  validates :owner, presence: true

  def public?
    public
  end

  def collaboration_permissions(user)
    collaboration = document_collaborations.find_by(user: user)
    collaboration ? collaboration.permissions : []
  end
end
