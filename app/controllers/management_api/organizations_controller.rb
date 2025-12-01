# frozen_string_literal: true

module ManagementAPI
  class OrganizationsController < BaseController
    before_action :find_organization, only: [:show, :update, :destroy, :suspend, :unsuspend]

    # GET /api/v2/organizations
    # List all organizations
    def index
      organizations = Organization.present.order(:name)

      if api_params["query"].present?
        organizations = organizations.where("name LIKE ? OR permalink LIKE ?",
                                            "%#{api_params['query']}%",
                                            "%#{api_params['query']}%")
      end

      render_success(
        organizations: organizations.map { |org| serialize_organization(org) }
      )
    end

    # GET /api/v2/organizations/:id
    # Get a single organization
    def show
      render_success(
        organization: serialize_organization(@organization)
      )
    end

    # POST /api/v2/organizations
    # Create a new organization
    def create
      owner = find_owner

      organization = Organization.new(organization_params)
      organization.owner = owner

      if organization.save
        # Add owner as admin user to the organization
        organization.organization_users.create!(
          user: owner,
          admin: true,
          all_servers: true
        )

        render_success(
          organization: serialize_organization(organization)
        ), status: :created
      else
        render_error "ValidationError",
                     message: "Failed to create organization",
                     details: { errors: organization.errors.as_json }
      end
    end

    # PATCH /api/v2/organizations/:id
    # Update an organization
    def update
      if @organization.update(organization_params)
        render_success(
          organization: serialize_organization(@organization)
        )
      else
        render_error "ValidationError",
                     message: "Failed to update organization",
                     details: { errors: @organization.errors.as_json }
      end
    end

    # DELETE /api/v2/organizations/:id
    # Delete an organization
    def destroy
      @organization.soft_destroy
      render_success(
        message: "Organization deleted successfully"
      )
    end

    # POST /api/v2/organizations/:id/suspend
    # Suspend an organization
    def suspend
      reason = api_params["reason"] || "Suspended via API"
      @organization.suspended_at = Time.now
      @organization.suspension_reason = reason
      @organization.save!

      render_success(
        organization: serialize_organization(@organization),
        message: "Organization suspended"
      )
    end

    # POST /api/v2/organizations/:id/unsuspend
    # Unsuspend an organization
    def unsuspend
      @organization.suspended_at = nil
      @organization.suspension_reason = nil
      @organization.save!

      render_success(
        organization: serialize_organization(@organization),
        message: "Organization unsuspended"
      )
    end

    private

    def find_organization
      @organization = Organization.present.find_by!(permalink: params[:id]) ||
                      Organization.present.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      @organization = Organization.present.find(params[:id])
    end

    def find_owner
      if api_params["owner_email"].present?
        user = User.find_by!(email_address: api_params["owner_email"])
      elsif api_params["owner_id"].present?
        user = User.find(api_params["owner_id"])
      else
        raise ActiveRecord::RecordNotFound, "Owner must be specified via owner_email or owner_id"
      end
      user
    end

    def organization_params
      params.permit(:name, :permalink, :time_zone)
    end
  end
end
