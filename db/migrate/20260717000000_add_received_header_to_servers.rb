# frozen_string_literal: true

class AddReceivedHeaderToServers < ActiveRecord::Migration[7.0]

  def change
    add_column :servers, :received_header, :string,
               default: "from api (10-42-11-130.email.vs-ru.svc.cluster.local [10.42.11.130]) by VS with HTTP",
               null: false
  end

end
