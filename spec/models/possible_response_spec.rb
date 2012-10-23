require "spec_helper"

describe PossibleResponse do
  context 'validations' do
    # it {should validate_presence_of :question_id}
    it {should validate_presence_of :value}
    it {should validate_presence_of :possible_response_order}
    it {should validate_numericality_of :possible_response_order}
  end

  it "returns the calculated percentage value for possible response" do
    now = Time.now
    campaign = Factory(:campaign)
    question = Factory(:question, :script => Factory(:script))
    possible_response = Factory(:possible_response, question_id: question.id)
    answer = Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response, :question => question, :created_at => now)
    possible_response.stats({possible_response.id => 1},{question.id => 25}).should == {answer: "no_response", number: 1, percentage:  4}
  end

  it "should return response_for_answers" do
    campaign = Factory(:campaign)
    question1 = Factory(:question, :script => Factory(:script))
    possible_response1 = Factory(:possible_response, question_id: question1.id, value: "Hey")
    question2 = Factory(:question, :script => Factory(:script))
    possible_response2 = Factory(:possible_response, question_id: question2.id, value: "Bye")
    answer1 = Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response1, :question => question1)
    answer2 = Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response2, :question => question2)
    PossibleResponse.response_for_answers([answer1, answer2]).size.should eq(2)
  end

  it "should return possible_response_text for all persisted questions" do
    campaign = Factory(:campaign)
    question1 = Factory(:question, :script => Factory(:script))
    possible_response1 = Factory(:possible_response, question_id: question1.id, value: "Hey")
    question2 = Factory(:question, :script => Factory(:script))
    possible_response2 = Factory(:possible_response, question_id: question2.id, value: "Bye")
    answer1 = Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response1, :question => question1)
    answer2 = Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response2, :question => question2)
    possible_responses_data = {
      possible_response1.id => "Hey",
      possible_response2.id => "Bye"
    }
    PossibleResponse.possible_response_text([question1.id, question2.id], [answer1, answer2], possible_responses_data).should eq(["Hey", "Bye"])
  end

  it "should return possible_response_text for all persisted questions in correct order" do
     campaign = Factory(:campaign)
     question1 = Factory(:question, :script => Factory(:script))
     possible_response1 = Factory(:possible_response, question_id: question1.id, value: "Hey")
     question2 = Factory(:question, :script => Factory(:script))
     possible_response2 = Factory(:possible_response, question_id: question2.id, value: "Bye")
     answer1 = Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response1, :question => question1)
     answer2 = Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response2, :question => question2)
     possible_responses_data = {
       possible_response1.id => "Hey",
       possible_response2.id => "Bye"
     }
     PossibleResponse.possible_response_text([question2.id, question1.id], [answer1, answer2], possible_responses_data).should eq(["Bye", "Hey"])
   end

   it "should return possible_response_text as blank for deleted responses" do
       campaign = Factory(:campaign)
       question1 = Factory(:question, :script => Factory(:script))
       possible_response1 = Factory(:possible_response, question_id: question1.id, value: "Hey")
       question2 = Factory(:question, :script => Factory(:script))
       possible_response2 = Factory(:possible_response, question_id: question2.id, value: "Bye")
       answer1 = Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response1, :question => question1)
       answer2 = Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response2, :question => question2)
       possible_responses_data = {
         possible_response1.id => "Hey",
         possible_response2.id => "Bye"
       }
       PossibleResponse.possible_response_text([question2.id, 3454 ,question1.id], [answer1, answer2], possible_responses_data).should eq(["Bye", "", "Hey"])
     end


end
