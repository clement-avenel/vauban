# frozen_string_literal: true

module Vauban
  class Relationship
    attr_reader :name, :subject_class, :object_class, :inverse

    def initialize(name, subject_class, object_class, inverse: nil)
      @name = name
      @subject_class = subject_class
      @object_class = object_class
      @inverse = inverse
    end

    def self.define(name, subject_class, object_class, inverse: nil)
      new(name, subject_class, object_class, inverse: inverse)
    end

    def check?(subject, object)
      # Check if a relationship exists between subject and object
      # This can be overridden in subclasses for specific relationship types
      false
    end
  end
end
