# frozen_string_literal: true

module Vauban
  module Api
    # Base controller for permissions API
    # This is a template that can be included in your application's API controllers
    class PermissionsController
      def self.included(base)
        base.class_eval do
          def check
            resources = parse_resources(params[:resources])
            permissions = Vauban.batch_permissions(current_user, resources)

            render json: serialize_permissions(permissions)
          end

          def schema
            render json: {
              resources: Vauban::Registry.resources.map do |resource_class|
                policy = Vauban::Registry.policy_for(resource_class)
                next unless policy

                {
                  type: resource_class.name,
                  permissions: policy.available_permissions.map(&:to_s),
                  relationships: policy.relationships.keys.map(&:to_s)
                }
              end.compact
            }
          end

          private

          def parse_resources(resource_params)
            Array(resource_params).map { |r| find_resource(r) }
          end

          def find_resource(resource_param)
            if resource_param.is_a?(String)
              type, id = resource_param.split(":")
              type.constantize.find(id)
            elsif resource_param.is_a?(Hash)
              resource_param[:type].constantize.find(resource_param[:id])
            else
              resource_param
            end
          end

          def serialize_permissions(permissions)
            {
              permissions: permissions.map do |resource, perms|
                {
                  resource: {
                    type: resource.class.name,
                    id: resource.id
                  },
                  permissions: perms
                }
              end
            }
          end
        end
      end
    end
  end
end
