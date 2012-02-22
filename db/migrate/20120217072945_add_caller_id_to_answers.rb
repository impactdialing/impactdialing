class AddCallerIdToAnswers < ActiveRecord::Migration
  def self.up
  	add_column :answers, :caller_id, :integer
  end

  def self.down
  	remove_column :answers, :caller_id
  end
end
