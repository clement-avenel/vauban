# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vauban::AllowWhere do
  describe ".record_matches_hash?" do
    it "returns true for empty hash" do
      record = double("Record")
      expect(described_class.record_matches_hash?(record, {})).to be true
      expect(described_class.record_matches_hash?(record, nil)).to be true
    end

    it "returns true when all attributes match" do
      record = double("Document", owner_id: 1, public: false)
      expect(described_class.record_matches_hash?(record, { owner_id: 1, public: false })).to be true
    end

    it "returns false when an attribute does not match" do
      record = double("Document", owner_id: 1)
      expect(described_class.record_matches_hash?(record, { owner_id: 99 })).to be false
    end

    it "treats array values as IN (include?)" do
      record = double("Document", owner_id: 2)
      expect(described_class.record_matches_hash?(record, { owner_id: [ 1, 2, 3 ] })).to be true
      record2 = double("Document", owner_id: 99)
      expect(described_class.record_matches_hash?(record2, { owner_id: [ 1, 2, 3 ] })).to be false
    end

    it "returns false when record does not respond to a key" do
      record = double("Record")
      allow(record).to receive(:respond_to?).with(:missing_attr).and_return(false)
      expect(described_class.record_matches_hash?(record, { missing_attr: 1 })).to be false
    end

    it "supports nested association hash" do
      owner = double("User", id: 10)
      record = double("Document", owner: owner)
      expect(described_class.record_matches_hash?(record, { owner: { id: 10 } })).to be true
    end

    it "returns false when nested value does not match" do
      owner = double("User", id: 10)
      record = double("Document", owner: owner)
      expect(described_class.record_matches_hash?(record, { owner: { id: 99 } })).to be false
    end

    it "returns false when association is nil" do
      record = double("Document", owner: nil)
      expect(described_class.record_matches_hash?(record, { owner: { id: 1 } })).to be false
    end
  end

  describe ".build_scope" do
    it "returns model_class.all when hashes is empty" do
      model = Class.new do
        def self.all
          :all
        end
      end
      expect(described_class.build_scope(model, [])).to eq(:all)
    end

    it "returns model_class.all when model does not respond to :where" do
      model = Class.new do
        def self.all
          :all
        end
      end
      expect(described_class.build_scope(model, [ { id: 1 } ])).to eq(:all)
    end

    it "builds a relation from a single condition hash" do
      chain = double("Chain", or: nil, distinct: nil)
      allow(chain).to receive(:where).and_return(chain)
      model = Class.new do
        def self.all
          @chain ||= Object.new.tap do |c|
            def c.where(*); self; end
            def c.or(*); self; end
            def c.distinct; self; end
          end
        end
      end
      result = described_class.build_scope(model, [ { owner_id: 1 } ])
      expect(result).to be_an(Object)
    end
  end
end
