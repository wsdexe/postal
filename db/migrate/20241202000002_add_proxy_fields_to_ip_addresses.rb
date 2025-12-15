# frozen_string_literal: true

class AddProxyFieldsToIPAddresses < ActiveRecord::Migration[7.0]

  def change
    add_column :ip_addresses, :proxy_port, :integer, default: 1080
    add_column :ip_addresses, :proxy_username, :string
    add_column :ip_addresses, :proxy_password, :string
    add_column :ip_addresses, :verified_at, :datetime
    add_column :ip_addresses, :verification_error, :string
  end

end
