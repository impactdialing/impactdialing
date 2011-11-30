require "spec_helper"

describe PossibleResponse do
  
  it "returns the calculated percentage value for possible response" do
    possible_response = Factory(:possible_response)
    # answer1 = Factory(:answer, :possible_response => possible_response)
    # answer2 = Factory(:answer, :possible_response => possible_response)
    date = Time.now
    ans = mock
    possible_response.stub!(:answers).and_return(ans)
    ans.stub!(:answered_within).with(date, date).and_return(ans)
    ans.stub!(:length).and_return(5)
    total_answers = 25
    possible_response.stats(date, date, total_answers).should == {answer: "no_response", number: 5, percentage:  20}
  end
  
end
