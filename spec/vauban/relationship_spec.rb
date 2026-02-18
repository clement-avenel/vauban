# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vauban::Relationship do
  let(:subject_class) { Class.new }
  let(:object_class) { Class.new }
  let(:subject) { double("Subject") }
  let(:object) { double("Object") }

  before do
    Vauban::Registry.initialize_registry
    stub_const("SubjectClass", subject_class)
    stub_const("ObjectClass", object_class)
  end

  describe ".define" do
    it "creates a new relationship" do
      relationship = Vauban::Relationship.define(:owns, SubjectClass, ObjectClass)
      expect(relationship).to be_a(Vauban::Relationship)
    end

    it "sets relationship name" do
      relationship = Vauban::Relationship.define(:owns, SubjectClass, ObjectClass)
      expect(relationship.name).to eq(:owns)
    end

    it "sets subject and object classes" do
      relationship = Vauban::Relationship.define(:owns, SubjectClass, ObjectClass)
      expect(relationship.subject_class).to eq(SubjectClass)
      expect(relationship.object_class).to eq(ObjectClass)
    end

    it "accepts inverse parameter" do
      relationship = Vauban::Relationship.define(:owns, SubjectClass, ObjectClass, inverse: :owned_by)
      expect(relationship.inverse).to eq(:owned_by)
    end

    it "sets inverse to nil by default" do
      relationship = Vauban::Relationship.define(:owns, SubjectClass, ObjectClass)
      expect(relationship.inverse).to be_nil
    end
  end

  describe "#initialize" do
    it "sets name, subject_class, and object_class" do
      relationship = Vauban::Relationship.new(:owns, SubjectClass, ObjectClass)
      expect(relationship.name).to eq(:owns)
      expect(relationship.subject_class).to eq(SubjectClass)
      expect(relationship.object_class).to eq(ObjectClass)
    end

    it "accepts inverse parameter" do
      relationship = Vauban::Relationship.new(:owns, SubjectClass, ObjectClass, inverse: :owned_by)
      expect(relationship.inverse).to eq(:owned_by)
    end

    it "sets inverse to nil by default" do
      relationship = Vauban::Relationship.new(:owns, SubjectClass, ObjectClass)
      expect(relationship.inverse).to be_nil
    end
  end

  describe "#check?" do
    it "returns false by default" do
      relationship = Vauban::Relationship.new(:owns, SubjectClass, ObjectClass)
      expect(relationship.check?(subject, object)).to be false
    end

    it "can be overridden in subclasses" do
      custom_relationship = Class.new(Vauban::Relationship) do
        def check?(subject, object)
          subject.owner == object
        end
      end

      owner = double("Owner")
      subject_with_owner = double("Subject", owner: owner)
      relationship = custom_relationship.new(:owns, SubjectClass, ObjectClass)

      expect(relationship.check?(subject_with_owner, owner)).to be true
      expect(relationship.check?(subject_with_owner, double("Other"))).to be false
    end
  end

  describe "attribute readers" do
    let(:relationship) do
      Vauban::Relationship.new(:owns, SubjectClass, ObjectClass, inverse: :owned_by)
    end

    it "provides read access to name" do
      expect(relationship.name).to eq(:owns)
    end

    it "provides read access to subject_class" do
      expect(relationship.subject_class).to eq(SubjectClass)
    end

    it "provides read access to object_class" do
      expect(relationship.object_class).to eq(ObjectClass)
    end

    it "provides read access to inverse" do
      expect(relationship.inverse).to eq(:owned_by)
    end
  end
end
