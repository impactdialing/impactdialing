require "spec_helper"

describe Script do

  it "restoring makes it active" do
    script = create(:script, :active => false)
    script.restore
    script.active?.should == true
  end

  xit "sorts by the updated date" do
    Script.record_timestamps = false
    older_script = create(:script).tap{|c| c.update_attribute(:updated_at, 2.days.ago)}
    newer_script = create(:script).tap{|c| c.update_attribute(:updated_at, 1.day.ago)}
    Script.record_timestamps = true
    Script.by_updated.all.should == [newer_script, older_script]
  end

  it "lists active scripts" do
    inactive = create(:script, :active => false)
    active = create(:script, :active => true)
    Script.active.should include(active)
  end

  describe "questions and responses" do
    it "gets all questions and responses" do
      script = create(:script)
      question = create(:question, :script => script)
      response_1 = create(:possible_response, :question => question)      
      another_response = create(:possible_response)
      script.questions_and_responses.should == {question.text => [question.possible_responses.first.value, response_1.value]}
    end
  end

  describe "deletion" do
    it "should not delete a script that is being used by a campaign" do
      script = create(:script)
      campaign = create(:campaign, script: script)
      script.active = false
      script.save.should be_false
      script.errors[:base].should == [I18n.t(:script_cannot_be_deleted)]
    end

    it "should delete a script that is not used by any campaign" do
      script = create(:script)
      campaign = create(:campaign)
      script.active = false
      script.save.should be_true
    end
  end
end
