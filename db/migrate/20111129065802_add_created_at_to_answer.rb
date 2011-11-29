class AddCreatedAtToAnswer < ActiveRecord::Migration
  def self.up
    add_column :answers, :created_at, :datetime
  end

  def self.down
    remove_column :answers, :created_at
  end
end
