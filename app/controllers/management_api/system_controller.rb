# frozen_string_literal: true

module ManagementAPI
  class SystemController < BaseController
    # GET /api/v2/system/info
    # Get system information
    def info
      render_success(
        version: Postal.version,
        ruby_version: RUBY_VERSION,
        rails_version: Rails::VERSION::STRING,
        database_connected: database_connected?,
        time: Time.now.utc.iso8601
      )
    end

    # GET /api/v2/system/health
    # Health check endpoint
    def health
      checks = {
        database: database_connected?,
        message_db: message_db_connected?
      }

      healthy = checks.values.all?

      render json: {
        status: healthy ? "healthy" : "unhealthy",
        checks: checks,
        time: Time.now.utc.iso8601
      }, status: healthy ? :ok : :service_unavailable
    end

    # GET /api/v2/system/stats
    # Get system-wide statistics
    def stats
      render_success(
        organizations: {
          total: Organization.present.count,
          suspended: Organization.present.where.not(suspended_at: nil).count
        },
        servers: {
          total: Server.present.count,
          suspended: Server.present.where.not(suspended_at: nil).count,
          by_mode: Server.present.group(:mode).count
        },
        users: {
          total: User.count,
          admins: User.where(admin: true).count
        },
        domains: {
          total: Domain.count,
          verified: Domain.verified.count
        },
        ip_pools: {
          total: IPPool.count
        },
        ip_addresses: {
          total: IPAddress.count
        }
      )
    end

    # GET /api/v2/system/ip_pools
    # List all IP pools
    def ip_pools
      pools = IPPool.includes(:ip_addresses).order(:name)
      render_success(
        ip_pools: pools.map do |pool|
          {
            id: pool.id,
            uuid: pool.uuid,
            name: pool.name,
            default: pool.default?,
            ip_addresses: pool.ip_addresses.map do |ip|
              {
                id: ip.id,
                ipv4: ip.ipv4,
                ipv6: ip.ipv6,
                hostname: ip.hostname,
                priority: ip.priority
              }
            end,
            created_at: pool.created_at&.iso8601
          }
        end
      )
    end

    # POST /api/v2/system/ip_pools
    # Create an IP pool
    def create_ip_pool
      pool = IPPool.new(ip_pool_params)

      if pool.save
        render_success(
          ip_pool: {
            id: pool.id,
            uuid: pool.uuid,
            name: pool.name,
            default: pool.default?
          }
        ), status: :created
      else
        render_error "ValidationError",
                     message: "Failed to create IP pool",
                     details: { errors: pool.errors.as_json }
      end
    end

    # DELETE /api/v2/system/ip_pools/:id
    # Delete an IP pool
    def destroy_ip_pool
      pool = IPPool.find(params[:id])
      pool.destroy
      render_success(message: "IP pool deleted successfully")
    end

    # POST /api/v2/system/ip_pools/:id/ip_addresses
    # Add an IP address to a pool
    def create_ip_address
      pool = IPPool.find(params[:id])
      ip_address = pool.ip_addresses.build(ip_address_params)

      if ip_address.save
        render_success(
          ip_address: {
            id: ip_address.id,
            ipv4: ip_address.ipv4,
            ipv6: ip_address.ipv6,
            hostname: ip_address.hostname,
            priority: ip_address.priority
          }
        ), status: :created
      else
        render_error "ValidationError",
                     message: "Failed to create IP address",
                     details: { errors: ip_address.errors.as_json }
      end
    end

    # DELETE /api/v2/system/ip_addresses/:id
    # Delete an IP address
    def destroy_ip_address
      ip_address = IPAddress.find(params[:id])
      ip_address.destroy
      render_success(message: "IP address deleted successfully")
    end

    private

    def database_connected?
      ActiveRecord::Base.connection.active?
    rescue StandardError
      false
    end

    def message_db_connected?
      # Try to connect to the message database
      server = Server.present.first
      return true unless server

      server.message_db.provisioner.present?
    rescue StandardError
      false
    end

    def ip_pool_params
      params.permit(:name, :default)
    end

    def ip_address_params
      params.permit(:ipv4, :ipv6, :hostname, :priority)
    end
  end
end
