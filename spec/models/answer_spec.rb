require "spec_helper"

describe Answer do
  before(:each) do
    @now = Time.now
    @campaign = Factory(:campaign)
    @voter1 = Factory(:voter, :campaign => @campaign)
    @voter2 = Factory(:voter, :campaign => Factory(:campaign))
    @voter3 = Factory(:voter, :campaign => @campaign)
    @voter4 = Factory(:voter, :campaign => Factory(:campaign))
    @answer1 = Factory(:answer, :voter => @voter1, :possible_response => Factory(:possible_response), :question => Factory(:question, :script => Factory(:script)), :created_at => @now - 2.days)
    @answer2 = Factory(:answer, :voter => @voter2, :possible_response => Factory(:possible_response), :question => Factory(:question, :script => Factory(:script)), :created_at => @now - 1.days)
    @answer3 = Factory(:answer, :voter => @voter3, :possible_response => Factory(:possible_response), :question => Factory(:question, :script => Factory(:script)), :created_at => @now)
    @answer4 = Factory(:answer, :voter => @voter4, :possible_response => Factory(:possible_response), :question => Factory(:question, :script => Factory(:script)), :created_at => @now+1.day)
  end
  it "should returns all the answers within the specified period" do
    Answer.within(@now, @now + 1.day).should == [@answer3, @answer4]
    Answer.within(@now + 2.day, @now + 3.day).should == []
    Answer.within(@now, @now).should == [@answer3, @answer4]
  end
  
  it "returns answers, which are answered by the voters of a particular campaign" do
    Answer.belong_to(@campaign.all_voters.collect{|v| v.id}).should == [@answer1, @answer3]
  end
end
