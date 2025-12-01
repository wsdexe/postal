# frozen_string_literal: true

module ManagementAPI
  class CredentialsController < BaseController
    before_action :find_server
    before_action :find_credential, only: [:show, :update, :destroy]

    # GET /api/v2/organizations/:organization_id/servers/:server_id/credentials
    # List all credentials for a server
    def index
      credentials = @server.credentials.order(:name)
      render_success(
        credentials: credentials.map { |credential| serialize_credential(credential) }
      )
    end

    # GET /api/v2/organizations/:organization_id/servers/:server_id/credentials/:id
    # Get a single credential
    def show
      render_success(
        credential: serialize_credential(@credential)
      )
    end

    # POST /api/v2/organizations/:organization_id/servers/:server_id/credentials
    # Create a new credential
    def create
      credential = @server.credentials.build(credential_params)

      if credential.save
        render_success(
          credential: serialize_credential(credential)
        ), status: :created
      else
        render_error "ValidationError",
                     message: "Failed to create credential",
                     details: { errors: credential.errors.as_json }
      end
    end

    # PATCH /api/v2/organizations/:organization_id/servers/:server_id/credentials/:id
    # Update a credential
    def update
      if @credential.update(credential_params)
        render_success(
          credential: serialize_credential(@credential)
        )
      else
        render_error "ValidationError",
                     message: "Failed to update credential",
                     details: { errors: @credential.errors.as_json }
      end
    end

    # DELETE /api/v2/organizations/:organization_id/servers/:server_id/credentials/:id
    # Delete a credential
    def destroy
      @credential.destroy
      render_success(
        message: "Credential deleted successfully"
      )
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

    def find_credential
      @credential = @server.credentials.find_by!(uuid: params[:id]) ||
                    @server.credentials.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      @credential = @server.credentials.find(params[:id])
    end

    def credential_params
      params.permit(:name, :type, :key, :hold)
    end
  end
end
