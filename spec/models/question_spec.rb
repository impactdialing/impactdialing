require "spec_helper"

describe Question do
  include Rails.application.routes.url_helpers

  let(:script) { Factory(:script) }
  let(:campaign) { Factory(:campaign, :script => script) }
  let(:voter) { Factory(:voter, :campaign => campaign) }

  it "should return questions answered in a time range" do
    now = Time.now
    question = Factory(:question, :script => script)
    answer1 = Factory(:answer, :voter => voter, campaign: campaign, :possible_response => Factory(:possible_response), :question => question, :created_at => (now - 2.days))
    answer2 = Factory(:answer, :voter => voter, campaign: campaign, :possible_response => Factory(:possible_response), :question => question, :created_at => (now - 1.days))
    answer3 = Factory(:answer, :voter => voter, campaign: campaign, :possible_response => Factory(:possible_response), :question => question, :created_at => (now + 1.minute))
    answer4 = Factory(:answer, :voter => voter, campaign: campaign, :possible_response => Factory(:possible_response), :question => question, :created_at => (now + 1.day))
    question.answered_within(now, now + 1.day, campaign.id).should == [answer3, answer4]
    question.answered_within(now + 2.days, now + 3.days, campaign.id).should == []
    question.answered_within(now, now + 1.day, campaign.id).should == [answer3, answer4]

  end

  it "returns questions answered by a voter" do
    answered_question = Factory(:question, :script => script, :text => "Q1?")
    pending_question = Factory(:question, :script => script, :text => "Q2?")
    Factory(:answer, :voter => voter, :possible_response => Factory(:possible_response), :question => answered_question, :created_at => (Time.now - 2.days))
    Question.answered_by(voter).should == [answered_question]
  end

  it "returns all questions unanswered when voter has not answered any question" do
    q1 = Factory(:question, :script => script, :text => "Q1?")
    q2 = Factory(:question, :script => script, :text => "Q2?")
    script.questions.not_answered_by(voter).should == [q1, q2]
  end

  it "returns questions not answered by a voter" do
    answered_question = Factory(:question, :script => script, :text => "Q1?")
    pending_question = Factory(:question, :script => script, :text => "Q2?")
    Factory(:answer, :voter => voter, :possible_response => Factory(:possible_response), :question => answered_question, :created_at => (Time.now - 2.days))
    script.questions.not_answered_by(voter).should == [pending_question]
  end

end
