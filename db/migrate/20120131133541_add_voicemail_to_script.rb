class AddVoicemailToScript < ActiveRecord::Migration
  def self.up
    add_column :scripts, :for_voicemail, :boolean
  end

  def self.down
    remove_column :scripts, :for_voicemail
  end
end
