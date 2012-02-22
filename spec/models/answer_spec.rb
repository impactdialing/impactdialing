require "spec_helper"

describe Answer do

  let(:campaign) { Factory(:campaign) }

  let(:voter_1) {  Factory(:voter, :campaign => campaign) }
  let(:voter_2) {  Factory(:voter, :campaign => Factory(:campaign)) }
  let(:voter_3) {  Factory(:voter, :campaign => campaign) }
  let(:voter_4) {  Factory(:voter, :campaign => Factory(:campaign)) }

  let(:caller_1) { Factory(:caller) }
  let(:caller_2) { Factory(:caller) }

  let(:answer_1) { Factory(:answer, :voter => voter_1, campaign: campaign, :possible_response => Factory(:possible_response), :question => Factory(:question, :script => Factory(:script)), :created_at => @now - 2.days, :caller => caller_1) }
  let(:answer_2) { Factory(:answer, :voter => voter_2, campaign: campaign, :possible_response => Factory(:possible_response), :question => Factory(:question, :script => Factory(:script)), :created_at => @now - 1.days, :caller => caller_2)}
  let(:answer_3) { Factory(:answer, :voter => voter_3, campaign: campaign, :possible_response => Factory(:possible_response), :question => Factory(:question, :script => Factory(:script)), :created_at => @now, :caller => caller_1) }
  let(:answer_4) { Factory(:answer, :voter => voter_4, campaign: campaign, :possible_response => Factory(:possible_response), :question => Factory(:question, :script => Factory(:script)), :created_at => @now+1.day, :caller => caller_2) }

  before(:each) do
    @now = Time.now
  end

  it "should returns all the answers within the specified period" do
    Answer.within(@now, @now + 1.day).should == [answer_3, answer_4]
    Answer.within(@now + 2.day, @now + 3.day).should == []
    Answer.within(@now, @now).should == [answer_3, answer_4]
  end

  it "returns all answers for the given campaign" do
    other_answer = Factory(:answer, :voter => voter_4, :campaign => Factory(:campaign), :possible_response => Factory(:possible_response), :question => Factory(:question, :script => Factory(:script)), :created_at => @now+1.day, :caller => caller_2)
    Answer.for_campaign(campaign).should == [answer_1, answer_2, answer_3, answer_4]
  end

end
