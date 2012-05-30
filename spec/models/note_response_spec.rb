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
  
  it "should return response_texts for notes" do
    campaign = Factory(:campaign)
    script = Factory(:script)
    note1 = Factory(:note, script: script, note:"note1")
    note2 = Factory(:note, script: script, note:"note2")
    note_response1 = Factory(:note_response, campaign: campaign, note_id: note1.id , voter: Factory(:voter), response: "Test")
    note_response2 = Factory(:note_response, campaign: campaign, note_id: note2.id, voter: Factory(:voter), response: "Test1")
    NoteResponse.response_texts([note1.id, note2.id],[note_response1, note_response2]).should eq(["Test", "Test1"])
  end

end
