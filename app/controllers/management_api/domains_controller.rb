# frozen_string_literal: true

module ManagementAPI
  class DomainsController < BaseController
    before_action :find_owner
    before_action :find_domain, only: [:show, :update, :destroy, :verify, :check_dns]

    # GET /api/v2/organizations/:organization_id/servers/:server_id/domains
    # GET /api/v2/organizations/:organization_id/domains
    # List all domains for a server or organization
    def index
      domains = @owner.domains.order(:name)
      render_success(
        domains: domains.map { |domain| serialize_domain(domain) }
      )
    end

    # GET /api/v2/organizations/:organization_id/servers/:server_id/domains/:id
    # GET /api/v2/organizations/:organization_id/domains/:id
    # Get a single domain
    def show
      render_success(
        domain: serialize_domain(@domain)
      )
    end

    # POST /api/v2/organizations/:organization_id/servers/:server_id/domains
    # POST /api/v2/organizations/:organization_id/domains
    # Create a new domain
    def create
      domain = @owner.domains.build(domain_params)
      domain.verification_method ||= "DNS"

      if domain.save
        render_success(
          domain: serialize_domain(domain)
        ), status: :created
      else
        render_error "ValidationError",
                     message: "Failed to create domain",
                     details: { errors: domain.errors.as_json }
      end
    end

    # PATCH /api/v2/organizations/:organization_id/servers/:server_id/domains/:id
    # PATCH /api/v2/organizations/:organization_id/domains/:id
    # Update a domain
    def update
      if @domain.update(domain_params)
        render_success(
          domain: serialize_domain(@domain)
        )
      else
        render_error "ValidationError",
                     message: "Failed to update domain",
                     details: { errors: @domain.errors.as_json }
      end
    end

    # DELETE /api/v2/organizations/:organization_id/servers/:server_id/domains/:id
    # DELETE /api/v2/organizations/:organization_id/domains/:id
    # Delete a domain
    def destroy
      @domain.destroy
      render_success(
        message: "Domain deleted successfully"
      )
    end

    # POST /api/v2/organizations/:organization_id/servers/:server_id/domains/:id/verify
    # POST /api/v2/organizations/:organization_id/domains/:id/verify
    # Verify a domain
    def verify
      if @domain.verified?
        render_success(
          domain: serialize_domain(@domain),
          message: "Domain is already verified"
        )
        return
      end

      if @domain.verification_method == "DNS"
        if @domain.verify_with_dns
          render_success(
            domain: serialize_domain(@domain.reload),
            message: "Domain verified successfully"
          )
        else
          render_error "VerificationFailed",
                       message: "DNS verification failed. Make sure the TXT record is set correctly.",
                       details: {
                         expected_record: @domain.dns_verification_string,
                         domain: @domain.name
                       }
        end
      else
        render_error "UnsupportedVerificationMethod",
                     message: "Only DNS verification is supported via API"
      end
    end

    # POST /api/v2/organizations/:organization_id/servers/:server_id/domains/:id/check_dns
    # POST /api/v2/organizations/:organization_id/domains/:id/check_dns
    # Check DNS records for a domain
    def check_dns
      @domain.check_dns
      @domain.save

      render_success(
        domain: serialize_domain(@domain.reload),
        dns_status: {
          spf: {
            status: @domain.spf_status,
            error: @domain.spf_error,
            expected_record: @domain.spf_record
          },
          dkim: {
            status: @domain.dkim_status,
            error: @domain.dkim_error,
            record_name: @domain.dkim_record_name,
            expected_record: @domain.dkim_record
          },
          mx: {
            status: @domain.mx_status,
            error: @domain.mx_error
          },
          return_path: {
            status: @domain.return_path_status,
            error: @domain.return_path_error,
            domain: @domain.return_path_domain
          }
        }
      )
    end

    private

    def find_owner
      if params[:server_id].present?
        organization = Organization.present.find_by!(permalink: params[:organization_id]) ||
                       Organization.present.find(params[:organization_id])
        @owner = organization.servers.present.find_by!(permalink: params[:server_id]) ||
                 organization.servers.present.find(params[:server_id])
      else
        @owner = Organization.present.find_by!(permalink: params[:organization_id]) ||
                 Organization.present.find(params[:organization_id])
      end
    rescue ActiveRecord::RecordNotFound
      if params[:server_id].present?
        organization = Organization.present.find(params[:organization_id])
        @owner = organization.servers.present.find(params[:server_id])
      else
        @owner = Organization.present.find(params[:organization_id])
      end
    end

    def find_domain
      @domain = @owner.domains.find_by!(uuid: params[:id]) ||
                @owner.domains.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      @domain = @owner.domains.find(params[:id])
    end

    def domain_params
      params.permit(:name, :verification_method, :outgoing, :incoming, :use_for_any)
    end
  end
end
