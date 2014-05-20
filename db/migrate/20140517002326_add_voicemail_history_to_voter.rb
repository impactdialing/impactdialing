class AddVoicemailHistoryToVoter < ActiveRecord::Migration
  def change
    add_column :voters, :voicemail_history, :string
  end
end
