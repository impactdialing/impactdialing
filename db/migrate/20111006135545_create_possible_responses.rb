class CreatePossibleResponses < ActiveRecord::Migration
  def self.up
    create_table :possible_responses do |t|
      t.column :question_id, :integer
      t.column :keypad, :integer
      t.column :value, :string
      t.column :retry, :boolean, :default=> false
    end
  end

  def self.down
    drop_table :possible_responses
  end
end
