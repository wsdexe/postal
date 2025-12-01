# frozen_string_literal: true

module ManagementAPI
  # The Management API provides full administrative control over Postal.
  # It allows automation of all administrative tasks including:
  # - Organization management
  # - Server management
  # - User management
  # - Domain management
  # - Credential management
  # - Route management
  # - System operations
  #
  # Authentication is performed using X-Management-API-Key header with a key
  # from an admin user or the MANAGEMENT_API_KEY environment variable.
  class BaseController < ActionController::Base
    skip_before_action :set_browser_id
    skip_before_action :verify_authenticity_token

    before_action :start_timer
    before_action :authenticate

    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :record_invalid

    private

    attr_reader :current_user

    # Start a timer to measure request processing time
    #
    # @return [void]
    def start_timer
      @start_time = Time.now.to_f
    end

    # Authenticate the request using X-Management-API-Key header
    #
    # @return [void]
    def authenticate
      key = request.headers["X-Management-API-Key"]

      if key.blank?
        render_error "AuthenticationRequired",
                     message: "X-Management-API-Key header is required"
        return
      end

      # Check against config file or environment variable
      configured_key = Postal::Config.management_api.api_key.presence || ENV["MANAGEMENT_API_KEY"]
      if configured_key.present? && ActiveSupport::SecurityUtils.secure_compare(key, configured_key)
        @current_user = nil # System-level access
        return
      end

      # Check against admin user API keys
      user = User.where(admin: true).find_by(uuid: key)
      if user
        @current_user = user
        return
      end

      render_error "InvalidAPIKey",
                   message: "The API key provided is not valid"
    end

    # Render a successful response
    #
    # @param data [Hash] the response data
    # @param status [Symbol] the HTTP status code
    # @return [void]
    def render_success(data, status: :ok)
      render json: {
        status: "success",
        time: (Time.now.to_f - @start_time).round(3),
        data: data
      }, status: status
    end

    # Render an error response
    #
    # @param code [String] error code
    # @param message [String] error message
    # @param details [Hash] additional error details
    # @param status [Symbol] HTTP status code
    # @return [void]
    def render_error(code, message: nil, details: {}, status: :unprocessable_entity)
      render json: {
        status: "error",
        time: (Time.now.to_f - @start_time).round(3),
        error: {
          code: code,
          message: message
        }.merge(details)
      }, status: status
    end

    # Handle record not found errors
    #
    # @param exception [ActiveRecord::RecordNotFound]
    # @return [void]
    def record_not_found(exception)
      render_error "RecordNotFound",
                   message: exception.message,
                   status: :not_found
    end

    # Handle record invalid errors
    #
    # @param exception [ActiveRecord::RecordInvalid]
    # @return [void]
    def record_invalid(exception)
      render_error "ValidationError",
                   message: exception.message,
                   details: { errors: exception.record.errors.as_json },
                   status: :unprocessable_entity
    end

    # Parse JSON body or return params
    #
    # @return [Hash]
    def api_params
      if request.content_type&.include?("application/json") && request.body.present?
        request.body.rewind
        body = request.body.read
        return JSON.parse(body) if body.present?
      end
      params.to_unsafe_hash.except("controller", "action", "format")
    rescue JSON::ParserError
      {}
    end

    # Serialize an organization for API response
    #
    # @param org [Organization]
    # @return [Hash]
    def serialize_organization(org)
      {
        id: org.id,
        uuid: org.uuid,
        name: org.name,
        permalink: org.permalink,
        time_zone: org.time_zone,
        status: org.status,
        suspended: org.suspended?,
        suspension_reason: org.suspension_reason,
        owner_id: org.owner_id,
        servers_count: org.servers.count,
        created_at: org.created_at&.iso8601,
        updated_at: org.updated_at&.iso8601
      }
    end

    # Serialize a server for API response
    #
    # @param server [Server]
    # @return [Hash]
    def serialize_server(server)
      {
        id: server.id,
        uuid: server.uuid,
        name: server.name,
        permalink: server.permalink,
        full_permalink: server.full_permalink,
        mode: server.mode,
        status: server.status,
        token: server.token,
        suspended: server.suspended?,
        suspension_reason: server.suspension_reason,
        send_limit: server.send_limit,
        message_retention_days: server.message_retention_days,
        raw_message_retention_days: server.raw_message_retention_days,
        organization_id: server.organization_id,
        organization_permalink: server.organization&.permalink,
        ip_pool_id: server.ip_pool_id,
        privacy_mode: server.privacy_mode,
        created_at: server.created_at&.iso8601,
        updated_at: server.updated_at&.iso8601
      }
    end

    # Serialize a user for API response
    #
    # @param user [User]
    # @return [Hash]
    def serialize_user(user)
      {
        id: user.id,
        uuid: user.uuid,
        first_name: user.first_name,
        last_name: user.last_name,
        name: user.name,
        email_address: user.email_address,
        admin: user.admin,
        time_zone: user.time_zone,
        email_verified: user.email_verified_at.present?,
        created_at: user.created_at&.iso8601,
        updated_at: user.updated_at&.iso8601
      }
    end

    # Serialize a domain for API response
    #
    # @param domain [Domain]
    # @return [Hash]
    def serialize_domain(domain)
      {
        id: domain.id,
        uuid: domain.uuid,
        name: domain.name,
        verified: domain.verified?,
        verified_at: domain.verified_at&.iso8601,
        verification_method: domain.verification_method,
        verification_token: domain.verification_token,
        dns_verification_string: domain.dns_verification_string,
        outgoing: domain.outgoing,
        incoming: domain.incoming,
        use_for_any: domain.use_for_any,
        owner_type: domain.owner_type,
        owner_id: domain.owner_id,
        spf_status: domain.spf_status,
        dkim_status: domain.dkim_status,
        mx_status: domain.mx_status,
        return_path_status: domain.return_path_status,
        spf_record: domain.spf_record,
        dkim_record: domain.dkim_record,
        dkim_record_name: domain.dkim_record_name,
        return_path_domain: domain.return_path_domain,
        dns_checked_at: domain.dns_checked_at&.iso8601,
        created_at: domain.created_at&.iso8601,
        updated_at: domain.updated_at&.iso8601
      }
    end

    # Serialize a credential for API response
    #
    # @param credential [Credential]
    # @return [Hash]
    def serialize_credential(credential)
      {
        id: credential.id,
        uuid: credential.uuid,
        name: credential.name,
        type: credential.type,
        key: credential.key,
        server_id: credential.server_id,
        hold: credential.hold,
        last_used_at: credential.last_used_at&.iso8601,
        usage_type: credential.usage_type,
        created_at: credential.created_at&.iso8601,
        updated_at: credential.updated_at&.iso8601
      }
    end

    # Serialize a route for API response
    #
    # @param route [Route]
    # @return [Hash]
    def serialize_route(route)
      {
        id: route.id,
        uuid: route.uuid,
        name: route.name,
        description: route.description,
        mode: route.mode,
        spam_mode: route.spam_mode,
        token: route.token,
        forward_address: route.forward_address,
        server_id: route.server_id,
        domain_id: route.domain_id,
        domain_name: route.domain&.name,
        endpoint_type: route.endpoint_type,
        endpoint_id: route.endpoint_id,
        created_at: route.created_at&.iso8601,
        updated_at: route.updated_at&.iso8601
      }
    end

    # Serialize a webhook for API response
    #
    # @param webhook [Webhook]
    # @return [Hash]
    def serialize_webhook(webhook)
      {
        id: webhook.id,
        uuid: webhook.uuid,
        name: webhook.name,
        url: webhook.url,
        enabled: webhook.enabled,
        sign: webhook.sign,
        all_events: webhook.all_events,
        server_id: webhook.server_id,
        created_at: webhook.created_at&.iso8601,
        updated_at: webhook.updated_at&.iso8601
      }
    end

    # Serialize an HTTP endpoint for API response
    #
    # @param endpoint [HTTPEndpoint]
    # @return [Hash]
    def serialize_http_endpoint(endpoint)
      {
        id: endpoint.id,
        uuid: endpoint.uuid,
        name: endpoint.name,
        url: endpoint.url,
        encoding: endpoint.encoding,
        format: endpoint.format,
        include_attachments: endpoint.include_attachments,
        strip_replies: endpoint.strip_replies,
        timeout: endpoint.timeout,
        server_id: endpoint.server_id,
        created_at: endpoint.created_at&.iso8601,
        updated_at: endpoint.updated_at&.iso8601
      }
    end

    # Serialize an SMTP endpoint for API response
    #
    # @param endpoint [SMTPEndpoint]
    # @return [Hash]
    def serialize_smtp_endpoint(endpoint)
      {
        id: endpoint.id,
        uuid: endpoint.uuid,
        name: endpoint.name,
        hostname: endpoint.hostname,
        port: endpoint.port,
        ssl_mode: endpoint.ssl_mode,
        server_id: endpoint.server_id,
        created_at: endpoint.created_at&.iso8601,
        updated_at: endpoint.updated_at&.iso8601
      }
    end

    # Serialize an address endpoint for API response
    #
    # @param endpoint [AddressEndpoint]
    # @return [Hash]
    def serialize_address_endpoint(endpoint)
      {
        id: endpoint.id,
        uuid: endpoint.uuid,
        address: endpoint.address,
        server_id: endpoint.server_id,
        created_at: endpoint.created_at&.iso8601,
        updated_at: endpoint.updated_at&.iso8601
      }
    end
  end
end
