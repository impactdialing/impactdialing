class CreateAnswers < ActiveRecord::Migration
  def self.up
    create_table :answers do |t|
      t.column :voter_id, :integer, :null => false
      t.column :question_id, :integer, :null => false
      t.column :possible_response_id, :integer, :null => false
    end
  end

  def self.down
    drop_table :answers
  end
end
