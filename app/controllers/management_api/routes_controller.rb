# frozen_string_literal: true

module ManagementAPI
  class RoutesController < BaseController
    before_action :find_server
    before_action :find_route, only: [:show, :update, :destroy]

    # GET /api/v2/organizations/:organization_id/servers/:server_id/routes
    # List all routes for a server
    def index
      routes = @server.routes.includes(:domain, :endpoint).order(:name)
      render_success({
        routes: routes.map { |route| serialize_route(route) }
      })
    end

    # GET /api/v2/organizations/:organization_id/servers/:server_id/routes/:id
    # Get a single route
    def show
      render_success({
        route: serialize_route(@route)
      })
    end

    # POST /api/v2/organizations/:organization_id/servers/:server_id/routes
    # Create a new route
    def create
      route = @server.routes.build(route_params)
      route._endpoint = api_params["endpoint"] if api_params["endpoint"].present?

      if route.save
        render_success({
          route: serialize_route(route)
        }, status: :created)
      else
        render_error "ValidationError",
                     message: "Failed to create route",
                     details: { errors: route.errors.as_json }
      end
    end

    # PATCH /api/v2/organizations/:organization_id/servers/:server_id/routes/:id
    # Update a route
    def update
      @route._endpoint = api_params["endpoint"] if api_params["endpoint"].present?

      if @route.update(route_params)
        render_success({
          route: serialize_route(@route)
        })
      else
        render_error "ValidationError",
                     message: "Failed to update route",
                     details: { errors: @route.errors.as_json }
      end
    end

    # DELETE /api/v2/organizations/:organization_id/servers/:server_id/routes/:id
    # Delete a route
    def destroy
      @route.destroy
      render_success({
        message: "Route deleted successfully"
      })
    end

    private

    def find_server
      organization = Organization.present.find_by(permalink: params[:organization_id]) ||
                     Organization.present.find(params[:organization_id])
      @server = organization.servers.present.find_by(permalink: params[:server_id]) ||
                organization.servers.present.find(params[:server_id])
    end

    def find_route
      @route = @server.routes.find_by(uuid: params[:id]) ||
               @server.routes.find(params[:id])
    end

    def route_params
      params.permit(:name, :domain_id, :spam_mode, :mode)
    end
  end
end
