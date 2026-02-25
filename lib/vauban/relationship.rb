# frozen_string_literal: true

module Vauban
  # Stores authorization relationship tuples: (subject, relation, object).
  #
  # Each row represents a single fact like "user 42 is an editor of document 7".
  # The tuple store is the foundation of Vauban's ReBAC engine — permissions
  # are derived by querying and traversing these relationships.
  #
  #   Vauban.grant!(user, :editor, document)
  #   # => creates (User, 42, "editor", Document, 7)
  #
  class Relationship < ActiveRecord::Base
    self.table_name = "vauban_relationships"

    belongs_to :subject, polymorphic: true
    belongs_to :object, polymorphic: true

    validates :relation, presence: true

    scope :for_subject, ->(subject) {
      where(subject_type: subject.class.name, subject_id: subject.id)
    }

    scope :for_object, ->(object) {
      where(object_type: object.class.name, object_id: object.id)
    }

    scope :with_relation, ->(relation) {
      where(relation: relation.to_s)
    }

    scope :with_any_relation, ->(relations) {
      where(relation: Array(relations).map(&:to_s))
    }

    scope :between, ->(subject, object) {
      for_subject(subject).for_object(object)
    }
  end
end
