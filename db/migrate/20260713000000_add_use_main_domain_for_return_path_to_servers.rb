# frozen_string_literal: true

class AddUseMainDomainForReturnPathToServers < ActiveRecord::Migration[7.0]

  def change
    add_column :servers, :use_main_domain_for_return_path, :boolean, default: true, null: false
  end

end
