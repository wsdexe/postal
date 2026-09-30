# frozen_string_literal: true

class AddIndividualDNSNamesToDomains < ActiveRecord::Migration[7.0]

  def change
    # NULL identifies existing domains. Do not populate these columns for them.
    add_column :domains, :dns_spf_domain, :string
    add_column :domains, :dns_dkim_selector, :string
    add_column :domains, :dns_return_path, :string
    add_column :domains, :dns_return_path_target, :string
    add_column :domains, :dns_verification_prefix, :string
    add_index :domains, :dns_return_path, unique: true
  end

end
