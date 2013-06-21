class AddAcceptedTosDate < ActiveRecord::Migration
  def change
    add_column :accounts, :tos_accepted_date, :datetime
  end
end
