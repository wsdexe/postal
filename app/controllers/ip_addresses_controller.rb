# frozen_string_literal: true

class IPAddressesController < ApplicationController

  before_action :admin_required
  before_action { @ip_pool = IPPool.find_by_uuid!(params[:ip_pool_id]) }
  before_action { params[:id] && @ip_address = @ip_pool.ip_addresses.find(params[:id]) }

  def new
    @ip_address = @ip_pool.ip_addresses.build
  end

  def create
    @ip_address = @ip_pool.ip_addresses.build(safe_params)
    if @ip_address.save
      redirect_to_with_json [:edit, @ip_pool]
    else
      render_form_errors "new", @ip_address
    end
  end

  def update
    if @ip_address.update(safe_params)
      redirect_to_with_json [:edit, @ip_pool]
    else
      render_form_errors "edit", @ip_address
    end
  end

  def destroy
    @ip_address.destroy
    redirect_to_with_json [:edit, @ip_pool]
  end

  def verify
    unless @ip_pool.proxy?
      redirect_to_with_json [:edit, @ip_pool], alert: "Verification is only available for proxy addresses."
      return
    end

    if @ip_address.verify_proxy!
      redirect_to_with_json [:edit, @ip_pool], notice: "Proxy verified successfully."
    else
      redirect_to_with_json [:edit, @ip_pool], alert: "Proxy verification failed: #{@ip_address.verification_error}"
    end
  end

  private

  def safe_params
    if @ip_pool.proxy?
      params.require(:ip_address).permit(:ipv4, :hostname, :priority, :proxy_port, :proxy_username, :proxy_password)
    else
      params.require(:ip_address).permit(:ipv4, :ipv6, :hostname, :priority)
    end
  end

end
