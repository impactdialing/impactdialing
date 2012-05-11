class AddOrderToPossibleResponse < ActiveRecord::Migration
  def self.up
    add_column(:possible_responses, :order, :integer)
  end

  def self.down
    remove_column(:possible_responses, :order)
  end
end
