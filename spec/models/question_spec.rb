require "spec_helper"

describe Question do
  
    it "should return questions answered in a time range" do
      question = Factory(:question, :script => Factory(:script))
      answer1 = Factory(:answer, :voter => Factory(:voter), :possible_response => Factory(:possible_response), :question => question, :created_at => (Time.now - 2.days))
      answer2 = Factory(:answer, :voter => Factory(:voter), :possible_response => Factory(:possible_response), :question => question, :created_at => (Time.now - 1.days))
      answer3 = Factory(:answer, :voter => Factory(:voter), :possible_response => Factory(:possible_response), :question => question, :created_at => (Time.now + 1.minute))
      answer4 = Factory(:answer, :voter => Factory(:voter), :possible_response => Factory(:possible_response), :question => question, :created_at => (Time.now + 1.day))
      question.answered_within(Time.now , Time.now + 1.day).should == [answer3, answer4]
      question.answered_within(Time.now + 2.days, Time.now + 3.days).should == []
      question.answered_within(Time.now, Time.now).should == [answer3, answer4]
      
    end

end
