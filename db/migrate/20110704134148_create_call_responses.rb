class CreateCallResponses < ActiveRecord::Migration
  def self.up
    create_table :call_responses do |t|
      t.integer :call_attempt_id
      t.string :response
      t.integer :recording_response_id

      t.timestamps
    end
  end

  def self.down
    drop_table :call_responses
  end
end
