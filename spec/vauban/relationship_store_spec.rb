# frozen_string_literal: true

require "spec_helper"
require "active_record"
require "vauban/relationship"

RSpec.describe Vauban::RelationshipStore do
  before(:all) do
    @original_connection_config = ActiveRecord::Base.connection_db_config.configuration_hash.dup rescue nil
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Schema.define do
      create_table :vauban_relationships, force: true do |t|
        t.string  :subject_type, null: false
        t.bigint  :subject_id,   null: false
        t.string  :relation,     null: false
        t.string  :object_type,  null: false
        t.bigint  :object_id,    null: false
        t.timestamps
      end

      add_index :vauban_relationships,
        [ :subject_type, :subject_id, :relation, :object_type, :object_id ],
        unique: true, name: "idx_vauban_rel_unique_tuple"

      create_table :rs_users, force: true do |t|
        t.string :name
      end

      create_table :rs_documents, force: true do |t|
        t.string :title
      end

      create_table :rs_teams, force: true do |t|
        t.string :name
      end
    end
  end

  after(:all) do
    ActiveRecord::Base.establish_connection(@original_connection_config) if @original_connection_config
  end

  before do
    stub_const("RsUser", Class.new(ActiveRecord::Base) { self.table_name = "rs_users" })
    stub_const("RsDocument", Class.new(ActiveRecord::Base) { self.table_name = "rs_documents" })
    stub_const("RsTeam", Class.new(ActiveRecord::Base) { self.table_name = "rs_teams" })
    Vauban::Relationship.delete_all
  end

  let(:alice) { RsUser.create!(name: "Alice") }
  let(:bob)   { RsUser.create!(name: "Bob") }
  let(:doc)   { RsDocument.create!(title: "Design Doc") }
  let(:team)  { RsTeam.create!(name: "Engineering") }

  describe ".grant!" do
    it "creates a relationship tuple" do
      Vauban.grant!(alice, :editor, doc)

      rel = Vauban::Relationship.last
      expect(rel.subject_type).to eq("RsUser")
      expect(rel.subject_id).to eq(alice.id)
      expect(rel.relation).to eq("editor")
      expect(rel.object_type).to eq("RsDocument")
      expect(rel.object_id).to eq(doc.id)
    end

    it "returns the relationship record" do
      rel = Vauban.grant!(alice, :editor, doc)
      expect(rel).to be_a(Vauban::Relationship)
      expect(rel).to be_persisted
    end

    it "is idempotent — granting the same tuple twice does not raise" do
      Vauban.grant!(alice, :editor, doc)
      expect { Vauban.grant!(alice, :editor, doc) }.not_to raise_error
      expect(Vauban::Relationship.count).to eq(1)
    end

    it "allows different relations between the same subject and object" do
      Vauban.grant!(alice, :editor, doc)
      Vauban.grant!(alice, :viewer, doc)
      expect(Vauban::Relationship.count).to eq(2)
    end

    it "allows the same relation from different subjects" do
      Vauban.grant!(alice, :editor, doc)
      Vauban.grant!(bob, :editor, doc)
      expect(Vauban::Relationship.count).to eq(2)
    end

    it "accepts string relations" do
      Vauban.grant!(alice, "editor", doc)
      expect(Vauban::Relationship.last.relation).to eq("editor")
    end

    it "works across different object types" do
      Vauban.grant!(alice, :member, team)
      Vauban.grant!(team, :viewer, doc)
      expect(Vauban::Relationship.count).to eq(2)
    end
  end

  describe ".revoke!" do
    it "removes the relationship tuple" do
      Vauban.grant!(alice, :editor, doc)
      Vauban.revoke!(alice, :editor, doc)
      expect(Vauban::Relationship.count).to eq(0)
    end

    it "returns the number of deleted rows" do
      Vauban.grant!(alice, :editor, doc)
      expect(Vauban.revoke!(alice, :editor, doc)).to eq(1)
    end

    it "returns 0 when the tuple does not exist" do
      expect(Vauban.revoke!(alice, :editor, doc)).to eq(0)
    end

    it "does not remove other relations between the same subject and object" do
      Vauban.grant!(alice, :editor, doc)
      Vauban.grant!(alice, :viewer, doc)
      Vauban.revoke!(alice, :editor, doc)
      expect(Vauban::Relationship.count).to eq(1)
      expect(Vauban::Relationship.last.relation).to eq("viewer")
    end
  end

  describe ".relation?" do
    it "returns true when the tuple exists" do
      Vauban.grant!(alice, :editor, doc)
      expect(Vauban.relation?(alice, :editor, doc)).to be true
    end

    it "returns false when the tuple does not exist" do
      expect(Vauban.relation?(alice, :editor, doc)).to be false
    end

    it "distinguishes between different relations" do
      Vauban.grant!(alice, :editor, doc)
      expect(Vauban.relation?(alice, :viewer, doc)).to be false
    end

    it "distinguishes between different subjects" do
      Vauban.grant!(alice, :editor, doc)
      expect(Vauban.relation?(bob, :editor, doc)).to be false
    end
  end

  describe ".relations_between" do
    it "returns all relation names as symbols" do
      Vauban.grant!(alice, :editor, doc)
      Vauban.grant!(alice, :viewer, doc)
      expect(Vauban.relations_between(alice, doc)).to contain_exactly(:editor, :viewer)
    end

    it "returns an empty array when no relations exist" do
      expect(Vauban.relations_between(alice, doc)).to eq([])
    end
  end

  describe ".subjects_with" do
    before do
      Vauban.grant!(alice, :editor, doc)
      Vauban.grant!(bob, :editor, doc)
      Vauban.grant!(alice, :viewer, doc)
    end

    it "returns relationships for a given relation and object" do
      results = Vauban.subjects_with(:editor, doc)
      expect(results.count).to eq(2)
      expect(results.pluck(:subject_id)).to contain_exactly(alice.id, bob.id)
    end

    it "filters by subject_type when provided" do
      Vauban.grant!(team, :viewer, doc)
      results = Vauban.subjects_with(:viewer, doc, subject_type: RsUser)
      expect(results.count).to eq(1)
      expect(results.first.subject_id).to eq(alice.id)
    end
  end

  describe ".has_relation? (graph resolution)" do
    let(:policy_class) do
      Class.new(Vauban::Policy) do
        resource RsDocument

        relation :viewer
        relation :viewer, via: { member: RsTeam }
        relation :editor, requires: [ :viewer ]
        relation :owner, requires: [ :editor, :viewer ]
      end
    end

    before do
      stub_const("RsDocumentPolicy", policy_class)
      Vauban::Registry.register(policy_class)
    end

    it "returns true when the direct relation exists" do
      Vauban.grant!(alice, :viewer, doc)
      expect(Vauban.has_relation?(alice, :viewer, doc)).to be true
    end

    it "returns true when an implying relation exists (editor implies viewer)" do
      Vauban.grant!(alice, :editor, doc)
      expect(Vauban.has_relation?(alice, :viewer, doc)).to be true
    end

    it "returns true when owner exists (implies viewer and editor)" do
      Vauban.grant!(alice, :owner, doc)
      expect(Vauban.has_relation?(alice, :viewer, doc)).to be true
      expect(Vauban.has_relation?(alice, :editor, doc)).to be true
    end

    it "returns false when no relation exists" do
      expect(Vauban.has_relation?(alice, :viewer, doc)).to be false
    end

    it "returns true when relation is satisfied via intermediate (user member of team, team has viewer on doc)" do
      Vauban.grant!(alice, :member, team)
      Vauban.grant!(team, :viewer, doc)
      expect(Vauban.has_relation?(alice, :viewer, doc)).to be true
    end

    it "falls back to single-relation check when policy has no relation schema" do
      team_policy = Class.new(Vauban::Policy) { resource RsTeam }
      Vauban::Registry.register(team_policy)

      Vauban.grant!(alice, :viewer, team)
      expect(Vauban.has_relation?(alice, :viewer, team)).to be true
      expect(Vauban.has_relation?(alice, :editor, team)).to be false
    end
  end

  describe ".objects_with_effective (graph resolution)" do
    let(:doc2) { RsDocument.create!(title: "Doc 2") }
    let(:policy_class) do
      Class.new(Vauban::Policy) do
        resource RsDocument

        relation :viewer
        relation :editor, requires: [ :viewer ]
        relation :owner, requires: [ :editor, :viewer ]
      end
    end

    before do
      stub_const("RsDocumentPolicy", policy_class)
      Vauban::Registry.register(policy_class)
    end

    it "returns objects where subject has the relation or any implying relation" do
      Vauban.grant!(alice, :viewer, doc)
      Vauban.grant!(alice, :editor, doc2)
      ids = Vauban.objects_with_effective(alice, :viewer, object_type: RsDocument).distinct.pluck(:object_id)
      expect(ids).to contain_exactly(doc.id, doc2.id)
    end

    it "without object_type falls back to direct relation only (no schema)" do
      Vauban.grant!(alice, :viewer, doc)
      Vauban.grant!(alice, :member, team)
      rels = Vauban.objects_with_effective(alice, :viewer)
      expect(rels.pluck(:object_id)).to include(doc.id)
    end
  end

  describe ".object_ids_for_relation (with via)" do
    let(:doc2) { RsDocument.create!(title: "Doc 2") }
    let(:policy_class) do
      Class.new(Vauban::Policy) do
        resource RsDocument

        relation :viewer
        relation :viewer, via: { member: RsTeam }
        relation :editor, requires: [ :viewer ]
        relation :owner, requires: [ :editor, :viewer ]
      end
    end

    before do
      stub_const("RsDocumentPolicy", policy_class)
      Vauban::Registry.register(policy_class)
    end

    it "returns direct object ids" do
      Vauban.grant!(alice, :viewer, doc)
      Vauban.grant!(alice, :editor, doc2)
      ids = Vauban.object_ids_for_relation(alice, :viewer, RsDocument)
      expect(ids).to contain_exactly(doc.id, doc2.id)
    end

    it "includes object ids from via path (user member of team, team has viewer on doc)" do
      Vauban.grant!(alice, :member, team)
      Vauban.grant!(team, :viewer, doc)
      ids = Vauban.object_ids_for_relation(alice, :viewer, RsDocument)
      expect(ids).to contain_exactly(doc.id)
    end
  end

  describe ".objects_with" do
    let(:doc2) { RsDocument.create!(title: "Another Doc") }

    before do
      Vauban.grant!(alice, :editor, doc)
      Vauban.grant!(alice, :editor, doc2)
      Vauban.grant!(alice, :member, team)
    end

    it "returns relationships for a given subject and relation" do
      results = Vauban.objects_with(alice, :editor)
      expect(results.count).to eq(2)
      expect(results.pluck(:object_id)).to contain_exactly(doc.id, doc2.id)
    end

    it "filters by object_type when provided" do
      results = Vauban.objects_with(alice, :editor, object_type: RsDocument)
      expect(results.count).to eq(2)

      results = Vauban.objects_with(alice, :member, object_type: RsTeam)
      expect(results.count).to eq(1)
    end
  end

  describe ".revoke_all!" do
    before do
      Vauban.grant!(alice, :editor, doc)
      Vauban.grant!(alice, :viewer, doc)
      Vauban.grant!(bob, :viewer, doc)
      Vauban.grant!(alice, :member, team)
    end

    it "removes all relationships for a subject" do
      Vauban.revoke_all!(subject: alice)
      expect(Vauban::Relationship.count).to eq(1)
      expect(Vauban::Relationship.last.subject_id).to eq(bob.id)
    end

    it "removes all relationships for an object" do
      Vauban.revoke_all!(object: doc)
      expect(Vauban::Relationship.count).to eq(1)
      expect(Vauban::Relationship.last.relation).to eq("member")
    end

    it "removes relationships matching both subject and object" do
      Vauban.revoke_all!(subject: alice, object: doc)
      expect(Vauban::Relationship.count).to eq(2) # bob->doc:viewer and alice->team:member
    end

    it "returns the number of deleted rows" do
      expect(Vauban.revoke_all!(subject: alice)).to eq(3)
    end

    it "raises when neither subject nor object is provided" do
      expect { Vauban.revoke_all! }.to raise_error(ArgumentError, /must provide at least one/)
    end
  end

  describe "Relationship model" do
    it "enforces uniqueness of the full tuple at the database level" do
      Vauban.grant!(alice, :editor, doc)
      expect {
        Vauban::Relationship.create!(
          subject_type: "RsUser", subject_id: alice.id,
          relation: "editor",
          object_type: "RsDocument", object_id: doc.id
        )
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "validates presence of relation" do
      rel = Vauban::Relationship.new(
        subject_type: "RsUser", subject_id: alice.id,
        relation: "",
        object_type: "RsDocument", object_id: doc.id
      )
      expect(rel).not_to be_valid
    end

    describe "scopes" do
      before do
        Vauban.grant!(alice, :editor, doc)
        Vauban.grant!(bob, :viewer, doc)
        Vauban.grant!(alice, :member, team)
      end

      it ".for_subject filters by subject" do
        expect(Vauban::Relationship.for_subject(alice).count).to eq(2)
      end

      it ".for_object filters by object" do
        expect(Vauban::Relationship.for_object(doc).count).to eq(2)
      end

      it ".with_relation filters by relation" do
        expect(Vauban::Relationship.with_relation(:editor).count).to eq(1)
      end

      it ".between filters by subject and object" do
        expect(Vauban::Relationship.between(alice, doc).count).to eq(1)
      end
    end
  end
end
