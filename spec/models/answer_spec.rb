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
