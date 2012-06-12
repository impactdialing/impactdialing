class RenameOrderToPossibleResponseOrder < ActiveRecord::Migration
  def self.up
    rename_column :possible_responses, :order, :possible_response_order
  end

  def self.down
    rename_column :possible_responses, :possible_response_order, :order
  end
end
