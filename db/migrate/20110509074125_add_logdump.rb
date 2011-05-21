class AddLogdump < ActiveRecord::Migration
  def self.up
    create_table :dumps, :force => true do |t|
      t.integer :request_id
      t.integer :first_line
      t.integer :last_line
      t.integer :completed_id
      t.integer :completed_lineno
      t.float :duration
      t.integer :status
      t.string :url
      t.integer :params_id
      t.integer :params_line
      t.string :params
      t.string :guid
      t.timestamps
    end
  end

  def self.down
    drop_table :Dumps
  end
end