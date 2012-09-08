require "spec_helper"

describe Script do

  it "restoring makes it active" do
    script = Factory(:script, :active => false)
    script.restore
    script.active?.should == true
  end

  it "sorts by the updated date" do
    Script.record_timestamps = false
    older_script = Factory(:script).tap{|c| c.update_attribute(:updated_at, 2.days.ago)}
    newer_script = Factory(:script).tap{|c| c.update_attribute(:updated_at, 1.day.ago)}
    Script.record_timestamps = true
    Script.by_updated.all.should == [newer_script, older_script]
  end

  it "lists active scripts" do
    inactive = Factory(:script, :active => false)
    active = Factory(:script, :active => true)
    Script.active.should == [active]
  end

  describe "questions and responses" do
    it "gets all questions and responses" do
      script = Factory(:script)
      question = Factory(:question, :script => script)
      response_1 = Factory(:possible_response, :question => question)
      response_2 = Factory(:possible_response, :question => question)
      another_response = Factory(:possible_response)
      script.questions_and_responses.should == {question.text => [response_1.value, response_2.value]}
    end
  end

  describe "deletion" do
    it "should not delete a script that is being used by a campaign" do
      script = Factory(:script)
      campaign = Factory(:campaign, script: script)
      script.active = false
      script.save.should be_false
      script.errors[:base].should == [I18n.t(:script_cannot_be_deleted)]
    end

    it "should delete a script that is not used by any campaign" do
      script = Factory(:script)
      campaign = Factory(:campaign)
      script.active = false
      script.save.should be_true
    end
  end
end
