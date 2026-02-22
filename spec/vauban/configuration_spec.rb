# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vauban::Configuration do
  describe "#initialize" do
    it "sets default current_user_method" do
      config = Vauban::Configuration.new
      expect(config.current_user_method).to eq(:current_user)
    end

    it "sets default cache_store to nil" do
      config = Vauban::Configuration.new
      expect(config.cache_store).to be_nil
    end

    it "sets default cache_ttl" do
      config = Vauban::Configuration.new
      expect(config.cache_ttl).to eq(3600)
    end

    it "sets default policy_paths" do
      config = Vauban::Configuration.new
      expect(config.policy_paths).to include("app/policies/**/*_policy.rb")
      expect(config.policy_paths).to include("packs/*/app/policies/**/*_policy.rb")
    end
  end

  describe "attribute accessors" do
    let(:config) { Vauban::Configuration.new }

    it "allows setting current_user_method" do
      config.current_user_method = :authenticated_user
      expect(config.current_user_method).to eq(:authenticated_user)
    end

    it "allows setting cache_store" do
      cache_store = double("CacheStore")
      config.cache_store = cache_store
      expect(config.cache_store).to eq(cache_store)
    end

    it "allows setting cache_ttl" do
      config.cache_ttl = 1800
      expect(config.cache_ttl).to eq(1800)
    end

    it "allows setting policy_paths" do
      custom_paths = [ "custom/policies/**/*_policy.rb" ]
      config.policy_paths = custom_paths
      expect(config.policy_paths).to eq(custom_paths)
    end
  end

  describe "integration with Vauban.configure" do
    after do
      Vauban.configuration = nil
    end

    it "can be configured via Vauban.configure" do
      Vauban.configure do |config|
        config.current_user_method = :authenticated_user
        config.cache_ttl = 1800
      end

      expect(Vauban.config.current_user_method).to eq(:authenticated_user)
      expect(Vauban.config.cache_ttl).to eq(1800)
    end
  end
end
