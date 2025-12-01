# frozen_string_literal: true

module ManagementAPI
  class ServersController < BaseController
    before_action :find_organization, except: [:index_all]
    before_action :find_server, only: [:show, :update, :destroy, :suspend, :unsuspend, :stats]

    # GET /api/v2/servers
    # List all servers across all organizations
    def index_all
      servers = Server.present.includes(:organization).order(:name)

      if api_params["query"].present?
        servers = servers.where("servers.name LIKE ? OR servers.permalink LIKE ?",
                                "%#{api_params['query']}%",
                                "%#{api_params['query']}%")
      end

      render_success(
        servers: servers.map { |server| serialize_server(server) }
      )
    end

    # GET /api/v2/organizations/:organization_id/servers
    # List all servers in an organization
    def index
      servers = @organization.servers.present.order(:name)
      render_success(
        servers: servers.map { |server| serialize_server(server) }
      )
    end

    # GET /api/v2/organizations/:organization_id/servers/:id
    # Get a single server
    def show
      render_success(
        server: serialize_server(@server)
      )
    end

    # POST /api/v2/organizations/:organization_id/servers
    # Create a new server
    def create
      server = @organization.servers.build(server_params)
      server.mode ||= "Live"

      if server.save
        render_success(
          server: serialize_server(server)
        ), status: :created
      else
        render_error "ValidationError",
                     message: "Failed to create server",
                     details: { errors: server.errors.as_json }
      end
    end

    # PATCH /api/v2/organizations/:organization_id/servers/:id
    # Update a server
    def update
      if @server.update(server_params)
        render_success(
          server: serialize_server(@server)
        )
      else
        render_error "ValidationError",
                     message: "Failed to update server",
                     details: { errors: @server.errors.as_json }
      end
    end

    # DELETE /api/v2/organizations/:organization_id/servers/:id
    # Delete a server
    def destroy
      @server.soft_destroy
      render_success(
        message: "Server deleted successfully"
      )
    end

    # POST /api/v2/organizations/:organization_id/servers/:id/suspend
    # Suspend a server
    def suspend
      reason = api_params["reason"] || "Suspended via API"
      @server.suspend(reason)

      render_success(
        server: serialize_server(@server.reload),
        message: "Server suspended"
      )
    end

    # POST /api/v2/organizations/:organization_id/servers/:id/unsuspend
    # Unsuspend a server
    def unsuspend
      @server.unsuspend

      render_success(
        server: serialize_server(@server.reload),
        message: "Server unsuspended"
      )
    end

    # GET /api/v2/organizations/:organization_id/servers/:id/stats
    # Get server statistics
    def stats
      render_success(
        server: {
          id: @server.id,
          uuid: @server.uuid,
          name: @server.name
        },
        statistics: {
          message_rate: @server.message_rate,
          held_messages: @server.held_messages,
          throughput: @server.throughput_stats,
          bounce_rate: @server.bounce_rate,
          domain_stats: {
            total: @server.domain_stats[0],
            unverified: @server.domain_stats[1],
            bad_dns: @server.domain_stats[2]
          },
          send_volume: @server.send_volume,
          send_limit: @server.send_limit,
          send_limit_approaching: @server.send_limit_approaching?,
          send_limit_exceeded: @server.send_limit_exceeded?,
          queue_size: @server.queue_size
        }
      )
    end

    private

    def find_organization
      @organization = Organization.present.find_by(permalink: params[:organization_id]) ||
                      Organization.present.find(params[:organization_id])
    end

    def find_server
      @server = @organization.servers.present.find_by(permalink: params[:id]) ||
                @organization.servers.present.find(params[:id])
    end

    def server_params
      params.permit(
        :name, :permalink, :mode, :send_limit,
        :message_retention_days, :raw_message_retention_days, :raw_message_retention_size,
        :allow_sender, :log_smtp_data, :postmaster_address,
        :spam_threshold, :spam_failure_threshold, :outbound_spam_threshold,
        :ip_pool_id, :privacy_mode, :domains_not_to_click_track
      )
    end
  end
end
