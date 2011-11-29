require "spec_helper"

describe Answer do
  
  it "should returns all the answers within the specified period" do
    answer1 = Factory(:answer, :voter => Factory(:voter), :possible_response => Factory(:possible_response), :question => Factory(:question, :script => Factory(:script)), :created_at => 2.days.ago)
    answer2 = Factory(:answer, :voter => Factory(:voter), :possible_response => Factory(:possible_response), :question => Factory(:question, :script => Factory(:script)), :created_at => 1.days.ago)
    answer3 = Factory(:answer, :voter => Factory(:voter), :possible_response => Factory(:possible_response), :question => Factory(:question, :script => Factory(:script)), :created_at => Time.now)
    answer4 = Factory(:answer, :voter => Factory(:voter), :possible_response => Factory(:possible_response), :question => Factory(:question, :script => Factory(:script)), :created_at => Time.now+1.day)
    Answer.answered_within(Time.now, Time.now + 1.day).should == [answer3, answer4]
    Answer.answered_within(Time.now + 2.day, Time.now + 3.day).should == []
    Answer.answered_within(Time.now, Time.now).should == [answer3, answer4]
  end

end
