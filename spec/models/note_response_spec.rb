require "spec_helper"

describe NoteResponse do  
  it "should return note ids ids for a campaign" do
    campaign = Factory(:campaign)
    script = Factory(:script)
    note1 = Factory(:note, script: script, note:"note1")
    note2 = Factory(:note, script: script, note:"note2")
    note_response1 = Factory(:note_response, campaign: campaign, note: note1 , voter: Factory(:voter))
    note_response2 = Factory(:note_response, campaign: campaign, note: note2, voter: Factory(:voter))
    NoteResponse.note_ids(campaign.id).should eq([note1.id, note2.id])
  end

end
