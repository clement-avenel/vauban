# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vauban::ResourceIdentifier do
  describe ".user_id_for" do
    it "returns 'user:nil' for nil user" do
      expect(described_class.user_id_for(nil)).to eq("user:nil")
    end

    it "returns 'user:id' for user with id" do
      user = double("User", id: 123)
      expect(described_class.user_id_for(user)).to eq("user:123")
    end

    it "returns 'user:key' for user with to_key" do
      user = double("User", to_key: [1, 2, 3])
      expect(described_class.user_id_for(user)).to eq("user:1-2-3")
    end

    it "returns 'user:object_id' for user without id or to_key" do
      user = double("User")
      allow(user).to receive(:object_id).and_return(12345)
      expect(described_class.user_id_for(user)).to eq("user:12345")
    end
  end

  describe ".user_key_for" do
    it "is an alias for user_id_for" do
      user = double("User", id: 456)
      expect(described_class.user_key_for(user)).to eq(described_class.user_id_for(user))
    end
  end

  describe ".user_info_string" do
    it "returns 'nil' for nil user" do
      expect(described_class.user_info_string(nil)).to eq("nil")
    end

    it "returns 'ClassName#id' for user with id" do
      user_class = double("UserClass", name: "User")
      user = double("User", id: 789, class: user_class)
      expect(described_class.user_info_string(user)).to eq("User#789")
    end

    it "returns class name for user without id" do
      user_class = double("UserClass", name: "User")
      user = double("User", class: user_class)
      expect(described_class.user_info_string(user)).to eq("User")
    end
  end

  describe ".resource_key_for" do
    it "returns 'nil' for nil resource" do
      expect(described_class.resource_key_for(nil)).to eq("nil")
    end

    it "returns 'ClassName:id' for resource with id" do
      resource_class = double("ResourceClass", name: "Document")
      resource = double("Resource", id: 123, class: resource_class)
      expect(described_class.resource_key_for(resource)).to eq("Document:123")
    end

    it "returns 'class:ClassName' for Class resource" do
      resource_class = Class.new do
        def self.name
          "Document"
        end
      end
      expect(described_class.resource_key_for(resource_class)).to eq("class:Document")
    end

    it "returns 'ClassName:object_id' for resource without id" do
      resource_class = double("ResourceClass", name: "Document")
      resource = double("Resource", class: resource_class)
      allow(resource).to receive(:object_id).and_return(99999)
      expect(described_class.resource_key_for(resource)).to eq("Document:99999")
    end
  end

  describe ".resource_info_string" do
    it "returns 'nil' for nil resource" do
      expect(described_class.resource_info_string(nil)).to eq("nil")
    end

    it "returns 'ClassName#id' for resource with id" do
      resource_class = double("ResourceClass", name: "Document")
      resource = double("Resource", id: 456, class: resource_class)
      expect(described_class.resource_info_string(resource)).to eq("Document#456")
    end

    it "returns class name for resource without id" do
      resource_class = double("ResourceClass", name: "Document")
      resource = double("Resource", class: resource_class)
      expect(described_class.resource_info_string(resource)).to eq("Document")
    end
  end
end
