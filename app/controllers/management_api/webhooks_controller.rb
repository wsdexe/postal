# frozen_string_literal: true

module ManagementAPI
  class WebhooksController < BaseController
    before_action :find_server
    before_action :find_webhook, only: [:show, :update, :destroy, :test]

    # GET /api/v2/organizations/:organization_id/servers/:server_id/webhooks
    # List all webhooks for a server
    def index
      webhooks = @server.webhooks.order(:name)
      render_success(
        webhooks: webhooks.map { |webhook| serialize_webhook(webhook) }
      )
    end

    # GET /api/v2/organizations/:organization_id/servers/:server_id/webhooks/:id
    # Get a single webhook
    def show
      render_success(
        webhook: serialize_webhook(@webhook)
      )
    end

    # POST /api/v2/organizations/:organization_id/servers/:server_id/webhooks
    # Create a new webhook
    def create
      webhook = @server.webhooks.build(webhook_params)

      if webhook.save
        render_success(
          webhook: serialize_webhook(webhook),
          status: :created
        )
      else
        render_error "ValidationError",
                     message: "Failed to create webhook",
                     details: { errors: webhook.errors.as_json }
      end
    end

    # PATCH /api/v2/organizations/:organization_id/servers/:server_id/webhooks/:id
    # Update a webhook
    def update
      if @webhook.update(webhook_params)
        render_success(
          webhook: serialize_webhook(@webhook)
        )
      else
        render_error "ValidationError",
                     message: "Failed to update webhook",
                     details: { errors: @webhook.errors.as_json }
      end
    end

    # DELETE /api/v2/organizations/:organization_id/servers/:server_id/webhooks/:id
    # Delete a webhook
    def destroy
      @webhook.destroy
      render_success(
        message: "Webhook deleted successfully"
      )
    end

    private

    def find_server
      organization = Organization.present.find_by(permalink: params[:organization_id]) ||
                     Organization.present.find(params[:organization_id])
      @server = organization.servers.present.find_by(permalink: params[:server_id]) ||
                organization.servers.present.find(params[:server_id])
    end

    def find_webhook
      @webhook = @server.webhooks.find_by(uuid: params[:id]) ||
                 @server.webhooks.find(params[:id])
    end

    def webhook_params
      params.permit(:name, :url, :enabled, :sign, :all_events)
    end
  end
end
