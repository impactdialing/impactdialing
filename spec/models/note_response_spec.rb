require "spec_helper"

describe NoteResponse do  
  it "should return note ids ids for a campaign" do
    campaign = create(:campaign)
    script = create(:script)
    note1 = create(:note, script: script, note:"note1")
    note2 = create(:note, script: script, note:"note2")
    note_response1 = create(:note_response, campaign: campaign, note: note1 , voter: create(:voter))
    note_response2 = create(:note_response, campaign: campaign, note: note2, voter: create(:voter))
    NoteResponse.note_ids(campaign.id).should eq([note1.id, note2.id])
  end
  
  it "should return response_texts for notes" do
    campaign = create(:campaign)
    script = create(:script)
    note1 = create(:note, script: script, note:"note1")
    note2 = create(:note, script: script, note:"note2")
    note_response1 = create(:note_response, campaign: campaign, note_id: note1.id , voter: create(:voter), response: "Test")
    note_response2 = create(:note_response, campaign: campaign, note_id: note2.id, voter: create(:voter), response: "Test1")
    NoteResponse.response_texts([note1.id, note2.id],[note_response1, note_response2]).should eq(["Test", "Test1"])
  end

end
