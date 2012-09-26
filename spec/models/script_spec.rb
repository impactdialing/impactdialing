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
    Script.active.should include(active)
  end

  it "lists robo scripts" do
    robo_script = Factory(:script, :robo => true)
    manual_script = Factory(:script, :robo => false)
    Script.robo.should == [robo_script]
  end

  it "lists interactive scripts" do
    script = Factory(:script, :robo => true, :for_voicemail => false)
    another_script = Factory(:script, :robo => true)
    script_for_voicemail = Factory(:script, :robo => true, :for_voicemail => true)
    Script.interactive.should == [script, another_script]
  end

  it "lists message scripts" do
    script = Factory(:script, :robo => true, :for_voicemail => false)
    another_script = Factory(:script, :robo => true)
    script_for_voicemail = Factory(:script, :robo => true, :for_voicemail => true)
    Script.message.should == [script_for_voicemail]
  end

  describe "default script" do
    before(:each) do
      account = Factory(:account)
      @script = Script.default_script(account)
    end


    it "should have name Demo Script" do
      @script.name.should == "Demo script"
    end

    it "should have FirstName, lastName and Phone as voter fields" do
      @script.voter_fields.should eq('["FirstName","LastName","Phone"]')
    end

    it "should have a default note" do
      @script.notes.length.should eq(1)
      @script.notes.first.note.should eq("What's your favorite feature?")
    end

    it "should add a default question" do
      @script.questions.length.should eq(1)
      @script.questions.first.text.should eq('How do you like the predictive dialer so far?')
    end

    it "should add a default question with 4 possible responses" do
      @script.questions.length.should eq(1)
      @script.questions.first.possible_responses.length.should eq(4)
    end

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
