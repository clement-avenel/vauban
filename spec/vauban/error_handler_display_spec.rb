# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vauban::ErrorHandler do
  describe ".display_name" do
    it "returns 'nil' for nil" do
      expect(described_class.display_name(nil)).to eq("nil")
    end

    it "returns 'ClassName#id' for object with id" do
      user_class = double("UserClass", name: "User")
      user = double("User", id: 789, class: user_class)
      expect(described_class.display_name(user)).to eq("User#789")
    end

    it "returns class name for object without id" do
      user_class = double("UserClass", name: "User")
      user = double("User", class: user_class)
      expect(described_class.display_name(user)).to eq("User")
    end

    it "returns class name for a Class" do
      klass = Class.new { def self.name = "Document" }
      expect(described_class.display_name(klass)).to eq("Document")
    end
  end
end
