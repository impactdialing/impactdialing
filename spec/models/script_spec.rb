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

  it "gives active scripts" do
    inactive = Factory(:script, :active => false)
    active = Factory(:script, :active => true)
    Script.active.should == [active]
  end

  it "lists robo scripts" do
    robo_script = Factory(:script, :robo => true)
    manual_script = Factory(:script, :robo => false)
    Script.robo.should == [robo_script]
  end
  
  describe "default script" do
    before(:each) do
      account = Factory(:account)
      @script = Script.default_script(account)
    end
    
  
    it "should have name Demo Script" do
      @script.name.should eq('Demo Script')    
    end
  
    it "should have FirstName, lastName and Phone as voter fields" do
      @script.voter_fields.should eq('["FirstName","LastName","Phone"]')
    end
  
    it "should have a default note" do
      @script.notes.length.should eq(1)
      @script.notes.first.note.should eq("What's your favorite thing about Impact Dialing?")  
    end
    
    it "should add a default question" do
      @script.questions.length.should eq(1)
      @script.questions.first.text.should eq('Are you ready to use Impact Dialing?')
    end
    
    it "should add a default question with 4 possible responses" do
      @script.questions.length.should eq(1)
      @script.questions.first.possible_responses.length.should eq(4)
    end
    
  end
end
