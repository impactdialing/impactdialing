class AddIndexToBlockedNumbersOnNumber < ActiveRecord::Migration
  def change
    add_index :blocked_numbers, :number, name: 'index_on_blocked_numbers_number'
  end
end
