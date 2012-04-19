class CreateCall < ActiveRecord::Migration
  def self.up
    create_table :calls do |t|
      t.integer :call_attempt_id
      t.string :state
      t.string :conference_name
      t.text :conference_history

      t.string :account_sid
      t.string :to_zip
      t.string :from_state
      t.string :called
      t.string :from_country
      t.string :caller_country
      t.string :called_zip
      t.string :direction
      t.string :from_city
      t.string :called_country
      t.string :caller_state
      t.string :call_sid
      t.string :called_state
      t.string :from
      t.string :caller_zip
      t.string :from_zip
      t.string :application_sid
      t.string :call_status
      t.string :to_city
      t.string :to_state
      t.string :to
      t.string :to_country
      t.string :caller_city
      t.string :api_version
      t.string :caller
      t.string :called_city
      t.string :answered_by

      t.timestamp :waiting_at
      t.timestamp :ended_at
      t.timestamps
    end
    
  end

  def self.down
    drop_table :calls
  end
end
