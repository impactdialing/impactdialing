require "spec_helper"

describe NoteResponse, :type => :model do  
  it "should return note ids ids for a campaign" do
    campaign = create(:campaign)
    script = create(:script)
    note1 = create(:note, script: script, note:"note1")
    note2 = create(:note, script: script, note:"note2")
    note_response1 = create(:note_response, campaign: campaign, note: note1 , voter: create(:voter))
    note_response2 = create(:note_response, campaign: campaign, note: note2, voter: create(:voter))
    expect(NoteResponse.note_ids(campaign.id)).to eq([note1.id, note2.id])
  end
  
  it "should return response_texts for notes" do
    campaign = create(:campaign)
    script = create(:script)
    note1 = create(:note, script: script, note:"note1")
    note2 = create(:note, script: script, note:"note2")
    note_response1 = create(:note_response, campaign: campaign, note_id: note1.id , voter: create(:voter), response: "Test")
    note_response2 = create(:note_response, campaign: campaign, note_id: note2.id, voter: create(:voter), response: "Test1")
    expect(NoteResponse.response_texts([note1.id, note2.id],[note_response1, note_response2])).to eq(["Test", "Test1"])
  end

end

# ## Schema Information
#
# Table name: `note_responses`
#
# ### Columns
#
# Name                   | Type               | Attributes
# ---------------------- | ------------------ | ---------------------------
# **`id`**               | `integer`          | `not null, primary key`
# **`voter_id`**         | `integer`          | `not null`
# **`note_id`**          | `integer`          | `not null`
# **`response`**         | `string(255)`      |
# **`call_attempt_id`**  | `integer`          |
# **`campaign_id`**      | `integer`          |
#
# ### Indexes
#
# * `call_attempt_id`:
#     * **`call_attempt_id`**
#     * **`id`**
# * `voter_id`:
#     * **`voter_id`**
#     * **`note_id`**
#
