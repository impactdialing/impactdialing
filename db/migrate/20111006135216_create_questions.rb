class CreateQuestions < ActiveRecord::Migration
  def self.up
    create_table :questions do |t|
      t.column :script_id, :integer, :null => false
      t.column :text, :text, :null => false
    end
  end

  def self.down
    drop_table :questions
  end
end
