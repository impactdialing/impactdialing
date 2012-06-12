class AddOrderToQuestion < ActiveRecord::Migration
  def self.up
    add_column(:questions, :order, :integer)
  end

  def self.down
    remove_column(:questions, :order)
  end
end
