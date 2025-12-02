# frozen_string_literal: true

module ManagementAPI
  class UsersController < BaseController
    before_action :find_user, only: [:show, :update, :destroy, :make_admin, :revoke_admin]

    # GET /api/v2/users
    # List all users
    def index
      users = User.order(:email_address)

      if api_params["query"].present?
        users = users.where("email_address LIKE ? OR first_name LIKE ? OR last_name LIKE ?",
                            "%#{api_params['query']}%",
                            "%#{api_params['query']}%",
                            "%#{api_params['query']}%")
      end

      if api_params["admin"].present?
        users = users.where(admin: api_params["admin"] == "true")
      end

      render_success({
        users: users.map { |user| serialize_user(user) }
      })
    end

    # GET /api/v2/users/:id
    # Get a single user
    def show
      render_success({
        user: serialize_user(@user),
        organizations: @user.organizations.present.map { |org| serialize_organization(org) }
      })
    end

    # POST /api/v2/users
    # Create a new user
    def create
      user = User.new(user_params)
      user.email_verified_at = Time.now if api_params["email_verified"]

      if user.save
        render_success({
          user: serialize_user(user)
        }, status: :created)
      else
        render_error "ValidationError",
                     message: "Failed to create user",
                     details: { errors: user.errors.as_json }
      end
    end

    # PATCH /api/v2/users/:id
    # Update a user
    def update
      if @user.update(user_params)
        render_success({
          user: serialize_user(@user)
        })
      else
        render_error "ValidationError",
                     message: "Failed to update user",
                     details: { errors: @user.errors.as_json }
      end
    end

    # DELETE /api/v2/users/:id
    # Delete a user
    def destroy
      if @user.admin? && User.where(admin: true).count <= 1
        render_error "CannotDeleteLastAdmin",
                     message: "Cannot delete the last admin user"
        return
      end

      @user.destroy
      render_success({
        message: "User deleted successfully"
      })
    end

    # POST /api/v2/users/:id/make_admin
    # Make a user an admin
    def make_admin
      @user.update!(admin: true)
      render_success({
        user: serialize_user(@user),
        message: "User is now an admin"
      })
    end

    # POST /api/v2/users/:id/revoke_admin
    # Revoke admin privileges
    def revoke_admin
      if User.where(admin: true).count <= 1
        render_error "CannotRevokeLastAdmin",
                     message: "Cannot revoke admin from the last admin user"
        return
      end

      @user.update!(admin: false)
      render_success({
        user: serialize_user(@user),
        message: "Admin privileges revoked"
      })
    end

    private

    def find_user
      @user = User.find_by(uuid: params[:id]) || User.find(params[:id])
    end

    def user_params
      params.permit(:first_name, :last_name, :email_address, :time_zone, :password)
    end
  end
end
