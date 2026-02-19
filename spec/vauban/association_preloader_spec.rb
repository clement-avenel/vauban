# frozen_string_literal: true

require "rails_helper"

RSpec.describe Vauban::AssociationPreloader do
  let(:user) { User.create!(email: "test@example.com", name: "Test User") }
  let(:document) { Document.create!(title: "Test", owner: user) }

  before do
    DummyAppSetup.setup_all
  end

  describe "#call" do
    it "returns early for empty resources" do
      preloader = described_class.new([])
      expect(preloader.call).to be_nil
    end

    it "preloads associations for ActiveRecord resources" do
      documents = [ document ]

      # Expect ActiveRecord::Associations::Preloader to be called
      expect(ActiveRecord::Associations::Preloader).to receive(:new).and_call_original

      preloader = described_class.new(documents)
      preloader.call
    end

    it "handles non-ActiveRecord resources gracefully" do
      non_ar_resource = double("Resource", class: Class.new)
      preloader = described_class.new([ non_ar_resource ])

      expect { preloader.call }.not_to raise_error
    end

    it "groups resources by class" do
      document2 = Document.create!(title: "Test 2", owner: user)
      user2 = User.create!(email: "test2@example.com", name: "Test User 2")

      resources = [ document, document2, user2 ]

      expect(ActiveRecord::Associations::Preloader).to receive(:new).at_least(:once).and_call_original

      preloader = described_class.new(resources)
      preloader.call
    end

    it "handles errors gracefully" do
      allow(ActiveRecord::Associations::Preloader).to receive(:new).and_raise(StandardError.new("Test error"))

      preloader = described_class.new([ document ])

      # Should not raise error, but log it
      expect { preloader.call }.not_to raise_error
    end

    it "returns early when ActiveRecord is not available" do
      # Stub the private method active_record_available? to return false
      preloader = described_class.new([ document ])
      allow(preloader).to receive(:active_record_available?).and_return(false)

      expect(preloader.call).to be_nil
    end
  end
end
