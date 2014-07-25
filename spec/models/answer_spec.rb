require "spec_helper"

describe Answer, :type => :model do

  let(:campaign) { create(:campaign) }

  let(:voter_1) {  create(:voter, :campaign => campaign) }
  let(:voter_2) {  create(:voter, :campaign => create(:campaign)) }
  let(:voter_3) {  create(:voter, :campaign => campaign) }
  let(:voter_4) {  create(:voter, :campaign => create(:campaign)) }

  let(:caller_1) { create(:caller) }
  let(:caller_2) { create(:caller) }

  let(:answer_1) { create(:answer, :voter => voter_1, campaign: campaign, :possible_response => create(:possible_response), :question => create(:question, :script => create(:script)), :created_at => @now - 2.days, :caller => caller_1) }
  let(:answer_2) { create(:answer, :voter => voter_2, campaign: campaign, :possible_response => create(:possible_response), :question => create(:question, :script => create(:script)), :created_at => @now - 1.days, :caller => caller_2)}
  let(:answer_3) { create(:answer, :voter => voter_3,
                                    :campaign => campaign,
                                    :created_at => @now,
                                    :caller => caller_1) }
  let(:answer_4) { create(:answer, :voter => voter_4, campaign: campaign, :possible_response => create(:possible_response), :question => create(:question, :script => create(:script)), :created_at => @now+1.day, :caller => caller_2) }

  before(:each) do
    @now = Time.now
  end

  it "should returns all the answers within the specified period" do
    expect(Answer.within(@now, @now + 1.day)).to eq([answer_3, answer_4])
    expect(Answer.within(@now + 2.day, @now + 3.day)).to eq([])
    expect(Answer.within(@now, @now+1.day)).to eq([answer_3, answer_4])
  end

  it "returns all answers for the given campaign" do
    other_answer = create(:answer,
                           :voter => voter_4,
                           :campaign => create(:campaign),
                           :possible_response => create(:possible_response),
                           :question => create(:question, :script => create(:script)),
                           :created_at => @now+1.day, :caller => caller_2)
    expect(Answer.with_campaign_id(campaign.id) - [answer_1, answer_2, answer_3, answer_4]).to be_empty
  end

  it "should return question ids for a campaign" do
    campaign = create(:campaign)
    script = create(:script)
    question1 = create(:question, script: script)
    question2 = create(:question, script: script)
    answer1 = create(:answer, campaign: campaign, question: question1 , voter: create(:voter), possible_response: create(:possible_response))
    answer2 = create(:answer, campaign: campaign, question: question2, voter: create(:voter), possible_response: create(:possible_response))
    expect(Answer.question_ids(campaign.id)).to eq([question1.id, question2.id])
  end

end

# ## Schema Information
#
# Table name: `answers`
#
# ### Columns
#
# Name                        | Type               | Attributes
# --------------------------- | ------------------ | ---------------------------
# **`id`**                    | `integer`          | `not null, primary key`
# **`voter_id`**              | `integer`          | `not null`
# **`question_id`**           | `integer`          | `not null`
# **`possible_response_id`**  | `integer`          | `not null`
# **`created_at`**            | `datetime`         |
# **`campaign_id`**           | `integer`          |
# **`caller_id`**             | `integer`          |
# **`call_attempt_id`**       | `integer`          |
#
# ### Indexes
#
# * `call_attempt_id`:
#     * **`call_attempt_id`**
#     * **`question_id`**
# * `index_answers_campaign_id_caller_id`:
#     * **`campaign_id`**
#     * **`caller_id`**
# * `index_answers_count_possible_response_campaign`:
#     * **`possible_response_id`**
#     * **`campaign_id`**
#     * **`caller_id`**
#     * **`created_at`**
# * `index_answers_on_campaign_created_at_possible_response`:
#     * **`campaign_id`**
#     * **`created_at`**
#     * **`possible_response_id`**
# * `index_answers_on_voter_id_and_question_id`:
#     * **`voter_id`**
#     * **`question_id`**
# * `index_distinct_question`:
#     * **`question_id`**
#     * **`campaign_id`**
#
