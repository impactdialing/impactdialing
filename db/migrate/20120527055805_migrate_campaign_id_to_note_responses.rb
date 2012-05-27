class MigrateCampaignIdToNoteResponses < ActiveRecord::Migration
  def self.up
    NoteResponse.connection.execute("update note_responses set campaign_id = (select campaign_id from voters where note_responses.voter_id = voters.id) where campaign_id is null");
  end

  def self.down
  end
end
