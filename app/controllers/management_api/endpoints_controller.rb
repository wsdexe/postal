# frozen_string_literal: true

module ManagementAPI
  class EndpointsController < BaseController
    before_action :find_server

    # GET /api/v2/organizations/:organization_id/servers/:server_id/endpoints
    # List all endpoints for a server
    def index
      endpoints = {
        http: @server.http_endpoints.map { |e| serialize_http_endpoint(e) },
        smtp: @server.smtp_endpoints.map { |e| serialize_smtp_endpoint(e) },
        address: @server.address_endpoints.map { |e| serialize_address_endpoint(e) }
      }

      render_success(endpoints: endpoints)
    end

    # POST /api/v2/organizations/:organization_id/servers/:server_id/endpoints/http
    # Create an HTTP endpoint
    def create_http
      endpoint = @server.http_endpoints.build(http_endpoint_params)

      if endpoint.save
        render_success(
          endpoint: serialize_http_endpoint(endpoint)
        ), status: :created
      else
        render_error "ValidationError",
                     message: "Failed to create HTTP endpoint",
                     details: { errors: endpoint.errors.as_json }
      end
    end

    # PATCH /api/v2/organizations/:organization_id/servers/:server_id/endpoints/http/:id
    # Update an HTTP endpoint
    def update_http
      endpoint = @server.http_endpoints.find_by!(uuid: params[:id])

      if endpoint.update(http_endpoint_params)
        render_success(
          endpoint: serialize_http_endpoint(endpoint)
        )
      else
        render_error "ValidationError",
                     message: "Failed to update HTTP endpoint",
                     details: { errors: endpoint.errors.as_json }
      end
    end

    # DELETE /api/v2/organizations/:organization_id/servers/:server_id/endpoints/http/:id
    # Delete an HTTP endpoint
    def destroy_http
      endpoint = @server.http_endpoints.find_by!(uuid: params[:id])
      endpoint.destroy
      render_success(message: "HTTP endpoint deleted successfully")
    end

    # POST /api/v2/organizations/:organization_id/servers/:server_id/endpoints/smtp
    # Create an SMTP endpoint
    def create_smtp
      endpoint = @server.smtp_endpoints.build(smtp_endpoint_params)

      if endpoint.save
        render_success(
          endpoint: serialize_smtp_endpoint(endpoint)
        ), status: :created
      else
        render_error "ValidationError",
                     message: "Failed to create SMTP endpoint",
                     details: { errors: endpoint.errors.as_json }
      end
    end

    # PATCH /api/v2/organizations/:organization_id/servers/:server_id/endpoints/smtp/:id
    # Update an SMTP endpoint
    def update_smtp
      endpoint = @server.smtp_endpoints.find_by!(uuid: params[:id])

      if endpoint.update(smtp_endpoint_params)
        render_success(
          endpoint: serialize_smtp_endpoint(endpoint)
        )
      else
        render_error "ValidationError",
                     message: "Failed to update SMTP endpoint",
                     details: { errors: endpoint.errors.as_json }
      end
    end

    # DELETE /api/v2/organizations/:organization_id/servers/:server_id/endpoints/smtp/:id
    # Delete an SMTP endpoint
    def destroy_smtp
      endpoint = @server.smtp_endpoints.find_by!(uuid: params[:id])
      endpoint.destroy
      render_success(message: "SMTP endpoint deleted successfully")
    end

    # POST /api/v2/organizations/:organization_id/servers/:server_id/endpoints/address
    # Create an address endpoint
    def create_address
      endpoint = @server.address_endpoints.build(address_endpoint_params)

      if endpoint.save
        render_success(
          endpoint: serialize_address_endpoint(endpoint)
        ), status: :created
      else
        render_error "ValidationError",
                     message: "Failed to create address endpoint",
                     details: { errors: endpoint.errors.as_json }
      end
    end

    # PATCH /api/v2/organizations/:organization_id/servers/:server_id/endpoints/address/:id
    # Update an address endpoint
    def update_address
      endpoint = @server.address_endpoints.find_by!(uuid: params[:id])

      if endpoint.update(address_endpoint_params)
        render_success(
          endpoint: serialize_address_endpoint(endpoint)
        )
      else
        render_error "ValidationError",
                     message: "Failed to update address endpoint",
                     details: { errors: endpoint.errors.as_json }
      end
    end

    # DELETE /api/v2/organizations/:organization_id/servers/:server_id/endpoints/address/:id
    # Delete an address endpoint
    def destroy_address
      endpoint = @server.address_endpoints.find_by!(uuid: params[:id])
      endpoint.destroy
      render_success(message: "Address endpoint deleted successfully")
    end

    private

    def find_server
      organization = Organization.present.find_by!(permalink: params[:organization_id]) ||
                     Organization.present.find(params[:organization_id])
      @server = organization.servers.present.find_by!(permalink: params[:server_id]) ||
                organization.servers.present.find(params[:server_id])
    rescue ActiveRecord::RecordNotFound
      organization = Organization.present.find(params[:organization_id])
      @server = organization.servers.present.find(params[:server_id])
    end

    def http_endpoint_params
      params.permit(:name, :url, :encoding, :format, :include_attachments, :strip_replies, :timeout)
    end

    def smtp_endpoint_params
      params.permit(:name, :hostname, :port, :ssl_mode)
    end

    def address_endpoint_params
      params.permit(:address)
    end
  end
end
