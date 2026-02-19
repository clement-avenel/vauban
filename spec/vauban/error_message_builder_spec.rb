# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vauban::ErrorMessageBuilder do
  describe ".build" do
    it "joins string parts with double newlines" do
      result = described_class.build("Part 1", "Part 2", "Part 3")
      expect(result).to eq("Part 1\n\nPart 2\n\nPart 3")
    end

    it "filters out nil parts" do
      result = described_class.build("Part 1", nil, "Part 2")
      expect(result).to eq("Part 1\n\nPart 2")
    end

    it "filters out empty string parts" do
      result = described_class.build("Part 1", "", "Part 2")
      expect(result).to eq("Part 1\n\nPart 2")
    end

    it "joins array parts with single newlines" do
      result = described_class.build("Part 1", ["Line 1", "Line 2"], "Part 2")
      expect(result).to eq("Part 1\n\nLine 1\nLine 2\n\nPart 2")
    end

    it "handles empty arrays" do
      result = described_class.build("Part 1", [], "Part 2")
      expect(result).to eq("Part 1\n\nPart 2")
    end

    it "handles mixed nil and empty parts" do
      result = described_class.build("Part 1", nil, "", "Part 2")
      expect(result).to eq("Part 1\n\nPart 2")
    end
  end

  describe ".section" do
    it "formats section with title and items" do
      result = described_class.section("Title:", ["Item 1", "Item 2"])
      expect(result).to eq("Title:\n  - Item 1\n  - Item 2")
    end

    it "returns nil for nil items" do
      expect(described_class.section("Title:", nil)).to be_nil
    end

    it "returns nil for empty items array" do
      expect(described_class.section("Title:", [])).to be_nil
    end

    it "handles single item" do
      result = described_class.section("Title:", ["Item 1"])
      expect(result).to eq("Title:\n  - Item 1")
    end
  end

  describe ".code_section" do
    it "formats code section with indentation" do
      result = described_class.code_section("Example:", ["class Foo", "  def bar", "  end"])
      expect(result).to eq("Example:\n\n     class Foo\n       def bar\n       end")
    end

    it "returns nil for nil code lines" do
      expect(described_class.code_section("Example:", nil)).to be_nil
    end

    it "returns nil for empty code lines array" do
      expect(described_class.code_section("Example:", [])).to be_nil
    end

    it "handles single line of code" do
      result = described_class.code_section("Example:", ["class Foo"])
      expect(result).to eq("Example:\n\n     class Foo")
    end
  end
end
