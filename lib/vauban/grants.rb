# frozen_string_literal: true

module Vauban
  # Declarative DSL for syncing ActiveRecord lifecycle to the relationship store.
  #
  #   class Document < ApplicationRecord
  #     extend Vauban::Grants
  #     grants_relation :owner, to: :owner
  #   end
  #
  #   class DocumentCollaboration < ApplicationRecord
  #     extend Vauban::Grants
  #     grants_relation :viewer, :editor, to: :user, on: :document do |record|
  #       perms = record.permissions
  #       rels = []
  #       rels << :viewer if perms.any?
  #       rels << :editor if perms.include?(:edit)
  #       rels
  #     end
  #   end
  module Grants
    # @param relations [Array<Symbol>] relation name(s) to manage
    # @param to [Symbol] association name for the subject (who gets the relation)
    # @param on [Symbol, nil] association name for the object (defaults to self)
    # @param block [Proc, nil] when given, called with the record; must return
    #   which of +relations+ to grant (the rest are revoked)
    def grants_relation(*relations, to:, on: nil, &block)
      relations = relations.map(&:to_s).freeze

      after_save do
        subject = send(to)
        object  = on ? send(on) : self
        next unless subject && object

        if block
          active = block.call(self).map(&:to_s)
          relations.each do |rel|
            active.include?(rel) ? Vauban.grant!(subject, rel, object) : Vauban.revoke!(subject, rel, object)
          end
        else
          rel = relations.first
          fk  = self.class.reflect_on_association(to).foreign_key.to_s
          if saved_change_to_attribute?(fk)
            prev_id = saved_change_to_attribute(fk).first
            if prev_id
              prev_subject = subject.class.find_by(id: prev_id)
              Vauban.revoke!(prev_subject, rel, object) if prev_subject
            end
          end
          Vauban.grant!(subject, rel, object)
        end
      end

      before_destroy do
        subject = send(to)
        object  = on ? send(on) : self
        next unless subject && object

        relations.each { |rel| Vauban.revoke!(subject, rel, object) }
      end
    end
  end
end

