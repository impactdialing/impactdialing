require "spec_helper"

describe Answer do
  it "should returns all the answers within the specified period" do
    now = Time.now
    answer1 = Factory(:answer, :voter => Factory(:voter), :possible_response => Factory(:possible_response), :question => Factory(:question, :script => Factory(:script)), :created_at => now - 2.days)
    answer2 = Factory(:answer, :voter => Factory(:voter), :possible_response => Factory(:possible_response), :question => Factory(:question, :script => Factory(:script)), :created_at => now - 1.days)
    answer3 = Factory(:answer, :voter => Factory(:voter), :possible_response => Factory(:possible_response), :question => Factory(:question, :script => Factory(:script)), :created_at => now)
    answer4 = Factory(:answer, :voter => Factory(:voter), :possible_response => Factory(:possible_response), :question => Factory(:question, :script => Factory(:script)), :created_at => now+1.day)
    Answer.within(now, now + 1.day).should == [answer3, answer4]
    Answer.within(now + 2.day, now + 3.day).should == []
    Answer.within(now, now).should == [answer3, answer4]
  end
end
