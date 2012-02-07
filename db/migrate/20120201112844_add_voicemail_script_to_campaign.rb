class AddVoicemailScriptToCampaign < ActiveRecord::Migration
  def self.up
    add_column(:campaigns, :voicemail_script_id, :integer)
  end

  def self.down
    remove_column(:campaigns, :voicemail_script_id)
  end
end
