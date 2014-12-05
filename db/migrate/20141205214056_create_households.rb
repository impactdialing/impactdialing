class CreateHouseholds < ActiveRecord::Migration
  def change
    create_table :households do |t|
      t.integer :account_id, null: false
      t.integer :campaign_id, null: false
      t.integer :voter_list_id, null: false
      t.integer :last_call_attempt_id
      
      t.string :phone, null: false
      t.integer :enabled, null: false, default: 0
      t.string :voicemail_history
      t.string :status, null: false, default: 'not called'
      t.datetime :presented_at, null: false

      t.timestamps
    end
  end
end
