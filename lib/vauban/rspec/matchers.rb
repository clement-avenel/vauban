# frozen_string_literal: true

require "rspec/expectations"

module Vauban
  module RSpec
    # Custom RSpec matchers for testing Vauban authorization policies.
    #
    # Usage in your spec_helper or rails_helper:
    #
    #   require "vauban/rspec"
    #
    # Then in specs:
    #
    #   expect(user).to be_able_to(:view, document)
    #   expect(user).not_to be_able_to(:edit, document)
    #   expect(user).to be_able_to(:view, document).with_context(admin: true)
    #
    #   expect(DocumentPolicy).to permit(:view).for(user, document)
    #   expect(DocumentPolicy).not_to permit(:edit).for(other_user, document)
    #
    module Matchers
      # Matcher: expect(user).to be_able_to(:action, resource)
      #
      # Checks Vauban.can?(user, action, resource, context: context).
      # Supports .with_context(hash) for contextual checks.
      class BeAbleTo
        def initialize(action, resource)
          @action = action
          @resource = resource
          @context = {}
        end

        def with_context(context)
          @context = context
          self
        end

        def matches?(user)
          @user = user
          Vauban.can?(user, @action, @resource, context: @context)
        end

        def failure_message
          "expected #{user_description} to be able to :#{@action} #{resource_description}#{context_description}"
        end

        def failure_message_when_negated
          "expected #{user_description} not to be able to :#{@action} #{resource_description}#{context_description}"
        end

        def description
          "be able to :#{@action} #{resource_description}#{context_description}"
        end

        private

        def user_description
          ErrorHandler.display_name(@user)
        end

        def resource_description
          ErrorHandler.display_name(@resource)
        end

        def context_description
          @context.empty? ? "" : " with context #{@context.inspect}"
        end
      end

      # Matcher: expect(PolicyClass).to permit(:action).for(user, resource)
      #
      # Checks the policy directly without going through Registry/cache.
      # Supports .with_context(hash) for contextual checks.
      class Permit
        def initialize(action)
          @action = action
          @context = {}
        end

        def for(user, resource)
          @user = user
          @resource = resource
          self
        end

        def with_context(context)
          @context = context
          self
        end

        def matches?(policy_class)
          raise ArgumentError, "Must call .for(user, resource) before matching" unless @user && @resource

          @policy_class = policy_class
          policy = policy_class.new(@user)
          policy.allowed?(@action, @resource, context: @context)
        end

        def failure_message
          "expected #{@policy_class.name} to permit :#{@action} for #{user_description} on #{resource_description}#{context_description}"
        end

        def failure_message_when_negated
          "expected #{@policy_class.name} not to permit :#{@action} for #{user_description} on #{resource_description}#{context_description}"
        end

        def description
          "permit :#{@action} for #{user_description} on #{resource_description}#{context_description}"
        end

        private

        def user_description
          ErrorHandler.display_name(@user)
        end

        def resource_description
          ErrorHandler.display_name(@resource)
        end

        def context_description
          @context.empty? ? "" : " with context #{@context.inspect}"
        end
      end
    end
  end
end

RSpec::Matchers.define :be_able_to do |action, resource|
  match do |user|
    @matcher = Vauban::RSpec::Matchers::BeAbleTo.new(action, resource)
    @matcher.with_context(@context) if @context
    @matcher.matches?(user)
  end

  chain :with_context do |context|
    @context = context
  end

  failure_message do
    @matcher.failure_message
  end

  failure_message_when_negated do
    @matcher.failure_message_when_negated
  end

  description do
    @matcher.description
  end
end

RSpec::Matchers.define :permit do |action|
  match do |policy_class|
    @permit_matcher = Vauban::RSpec::Matchers::Permit.new(action)
    @permit_matcher.for(@permit_user, @permit_resource)
    @permit_matcher.with_context(@permit_context) if @permit_context
    @permit_matcher.matches?(policy_class)
  end

  chain :for do |user, resource|
    @permit_user = user
    @permit_resource = resource
  end

  chain :with_context do |context|
    @permit_context = context
  end

  failure_message do
    @permit_matcher.failure_message
  end

  failure_message_when_negated do
    @permit_matcher.failure_message_when_negated
  end

  description do
    @permit_matcher.description
  end
end
