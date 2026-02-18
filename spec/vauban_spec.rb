# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vauban do
  it "has a version number" do
    expect(Vauban::VERSION).not_to be nil
  end

  describe ".configure" do
    it "allows configuration" do
      Vauban.configure do |config|
        config.current_user_method = :current_user
      end

      expect(Vauban.config.current_user_method).to eq(:current_user)
    end
  end
end

