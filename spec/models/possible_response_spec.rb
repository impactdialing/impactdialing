require "spec_helper"

describe PossibleResponse do
  
  it "returns the calculated percentage value for possible response" do
    now = Time.now
    campaign = Factory(:campaign)
    question = Factory(:question, :script => Factory(:script))
    possible_response = Factory(:possible_response, question_id: question.id)
    answer = Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response, :question => question, :created_at => now)
    possible_response.stats({possible_response.id => 1},{question.id => 25}).should == {answer: "no_response", number: 1, percentage:  4}
  end
  
end
