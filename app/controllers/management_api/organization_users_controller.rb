# frozen_string_literal: true

module ManagementAPI
  class OrganizationUsersController < BaseController
    before_action :find_organization
    before_action :find_organization_user, only: [:show, :update, :destroy]

    # GET /api/v2/organizations/:organization_id/users
    # List all users in an organization
    def index
      org_users = @organization.organization_users.includes(:user)

      render_success(
        users: org_users.map { |ou| serialize_organization_user(ou) }
      )
    end

    # GET /api/v2/organizations/:organization_id/users/:id
    # Get a single organization user
    def show
      render_success(
        organization_user: serialize_organization_user(@organization_user)
      )
    end

    # POST /api/v2/organizations/:organization_id/users
    # Add a user to an organization
    def create
      user = find_user_to_add

      # Check if user is already a member
      if @organization.organization_users.where(user: user).exists?
        render_error "AlreadyMember",
                     message: "User is already a member of this organization"
        return
      end

      org_user = @organization.organization_users.build(
        user: user,
        admin: api_params["admin"] == true,
        all_servers: api_params["all_servers"] == true
      )

      if org_user.save
        render_success(
          organization_user: serialize_organization_user(org_user)
        ), status: :created
      else
        render_error "ValidationError",
                     message: "Failed to add user to organization",
                     details: { errors: org_user.errors.as_json }
      end
    end

    # PATCH /api/v2/organizations/:organization_id/users/:id
    # Update a user's organization permissions
    def update
      update_params = {}
      update_params[:admin] = api_params["admin"] if api_params.key?("admin")
      update_params[:all_servers] = api_params["all_servers"] if api_params.key?("all_servers")

      if @organization_user.update(update_params)
        render_success(
          organization_user: serialize_organization_user(@organization_user)
        )
      else
        render_error "ValidationError",
                     message: "Failed to update organization user",
                     details: { errors: @organization_user.errors.as_json }
      end
    end

    # DELETE /api/v2/organizations/:organization_id/users/:id
    # Remove a user from an organization
    def destroy
      if @organization_user.user == @organization.owner
        render_error "CannotRemoveOwner",
                     message: "Cannot remove the owner from the organization"
        return
      end

      @organization_user.destroy
      render_success(
        message: "User removed from organization"
      )
    end

    # POST /api/v2/organizations/:organization_id/transfer_ownership
    # Transfer organization ownership to another user
    def transfer_ownership
      new_owner = find_user_to_add

      # Check if user is a member
      org_user = @organization.organization_users.find_by(user: new_owner)
      unless org_user
        render_error "NotAMember",
                     message: "User must be a member of the organization first"
        return
      end

      @organization.make_owner(new_owner)

      render_success(
        organization: serialize_organization(@organization.reload),
        message: "Ownership transferred successfully"
      )
    end

    private

    def find_organization
      @organization = Organization.present.find_by!(permalink: params[:organization_id]) ||
                      Organization.present.find(params[:organization_id])
    rescue ActiveRecord::RecordNotFound
      @organization = Organization.present.find(params[:organization_id])
    end

    def find_organization_user
      user = User.find_by!(uuid: params[:id]) || User.find(params[:id])
      @organization_user = @organization.organization_users.find_by!(user: user)
    rescue ActiveRecord::RecordNotFound
      user = User.find(params[:id])
      @organization_user = @organization.organization_users.find_by!(user: user)
    end

    def find_user_to_add
      if api_params["user_email"].present?
        User.find_by!(email_address: api_params["user_email"])
      elsif api_params["user_id"].present?
        User.find(api_params["user_id"])
      elsif api_params["user_uuid"].present?
        User.find_by!(uuid: api_params["user_uuid"])
      else
        raise ActiveRecord::RecordNotFound, "User must be specified via user_email, user_id, or user_uuid"
      end
    end

    def serialize_organization_user(org_user)
      {
        user: serialize_user(org_user.user),
        admin: org_user.admin,
        all_servers: org_user.all_servers,
        is_owner: org_user.user == @organization.owner,
        created_at: org_user.created_at&.iso8601,
        updated_at: org_user.updated_at&.iso8601
      }
    end
  end
end
