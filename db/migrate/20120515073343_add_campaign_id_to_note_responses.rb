class AddCampaignIdToNoteResponses < ActiveRecord::Migration
  def self.up
    add_column(:note_responses, :campaign_id, :integer)
    NoteResponse.connection.execute("update note_responses set campaign_id = (select campaign_id from voters where note_responses.voter_id = voters.id)");    
  end

  def self.down
    remove_column(:note_responses, :campaign_id)
  end
end
