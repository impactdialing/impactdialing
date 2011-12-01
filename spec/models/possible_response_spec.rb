require "spec_helper"

describe PossibleResponse do
  
  it "returns the calculated percentage value for possible response" do
    now = Time.now
    possible_response = Factory(:possible_response)
    answer = Factory(:answer, :voter => Factory(:voter),:possible_response => possible_response, :question => Factory(:question, :script => Factory(:script)), :created_at => now)
    possible_response.stats(now, now, 25).should == {answer: "no_response", number: 1, percentage:  4}
  end
  
end
