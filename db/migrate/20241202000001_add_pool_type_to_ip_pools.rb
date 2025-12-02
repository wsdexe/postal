# frozen_string_literal: true

class AddPoolTypeToIPPools < ActiveRecord::Migration[7.0]

  def change
    add_column :ip_pools, :pool_type, :string, default: "local", null: false
    add_index :ip_pools, :pool_type
  end

end
