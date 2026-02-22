# frozen_string_literal: true

module Vauban
  module Api
    # Include this concern in your API controller to expose permission endpoints.
    #
    #   class Api::PermissionsController < ApplicationController
    #     include Vauban::Api::PermissionsControllerConcern
    #   end
    #
    # Provides two actions:
    #   - check:  bulk-check permissions for a list of resources
    #   - schema: list all registered resource types, permissions, and relationships
    module PermissionsControllerConcern
      extend ActiveSupport::Concern

      def check
        resources = parse_resources(params[:resources])
        permissions = Vauban.batch_permissions(current_user, resources)

        render json: serialize_permissions(permissions)
      end

      def schema
        render json: {
          resources: Vauban::Registry.resources.filter_map do |resource_class|
            policy = Vauban::Registry.policy_for(resource_class)
            next unless policy

            {
              type: resource_class.name,
              permissions: policy.available_permissions.map(&:to_s),
              relationships: policy.relationships.keys.map(&:to_s)
            }
          end
        }
      end

      private

      def parse_resources(resource_params)
        Array(resource_params).map { |r| find_resource(r) }
      end

      def find_resource(param)
        case param
        when String
          type, id = param.split(":")
          type.constantize.find(id)
        when Hash, ActionController::Parameters
          type = param[:type] || param["type"]
          id   = param[:id]   || param["id"]
          type && id ? type.constantize.find(id) : param
        else
          param
        end
      end

      def serialize_permissions(permissions)
        {
          permissions: permissions.map do |resource, perms|
            {
              resource: { type: resource.class.name, id: resource.id },
              permissions: perms
            }
          end
        }
      end
    end
  end
end
