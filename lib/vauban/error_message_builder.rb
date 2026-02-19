# frozen_string_literal: true

module Vauban
  # Helper module for building error messages in a clean, readable way
  module ErrorMessageBuilder
    module_function

    # Build an error message from parts
    # Parts can be strings or arrays (which will be joined with newlines)
    # Empty/nil parts are automatically filtered out
    #
    # @param parts [Array<String, Array<String>, nil>] Message parts to join
    # @return [String] Formatted error message
    #
    # @example
    #   ErrorMessageBuilder.build(
    #     "Main error message",
    #     ["Detail 1", "Detail 2"],
    #     "Additional info" if condition
    #   )
    def build(*parts)
      parts
        .compact
        .map { |part| part.is_a?(Array) ? part.join("\n") : part }
        .reject(&:empty?)
        .join("\n\n")
    end

    # Build a section with a title and items
    #
    # @param title [String] Section title
    # @param items [Array<String>] List items (will be prefixed with "  - ")
    # @return [String, nil] Formatted section or nil if no items
    #
    # @example
    #   ErrorMessageBuilder.section("To fix this:", ["Step 1", "Step 2"])
    def section(title, items)
      return nil if items.nil? || items.empty?

      formatted_items = items.map { |item| "  - #{item}" }
      [title, *formatted_items].join("\n")
    end

    # Build a code block section
    #
    # @param title [String] Section title
    # @param code_lines [Array<String>] Lines of code
    # @return [String, nil] Formatted code section or nil if no code
    #
    # @example
    #   ErrorMessageBuilder.code_section("Example:", ["class Foo", "  def bar", "  end"])
    def code_section(title, code_lines)
      return nil if code_lines.nil? || code_lines.empty?

      formatted_code = code_lines.map { |line| "     #{line}" }.join("\n")
      [title, formatted_code].join("\n\n")
    end
  end
end
