# frozen_string_literal: true

class Document < ApplicationRecord
  extend Vauban::Grants

  belongs_to :owner, class_name: "User", foreign_key: "owner_id"
  has_many :document_collaborations, class_name: "DocumentCollaboration", dependent: :destroy
  has_many :collaborators, through: :document_collaborations, source: :user

  grants_relation :owner, to: :owner

  validates :title, presence: true
  validates :owner, presence: true

  def public?
    public
  end

  def collaboration_for(user)
    document_collaborations.includes(:document_collaboration_permissions).find_by(user: user)
  end
end
