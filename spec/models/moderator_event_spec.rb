require "spec_helper"

describe ModeratorEvent do
  
  before(:each) do
    class DummyClass
      include ModeratorEvent
    end
    @dummy_class = DummyClass.new
  end
  
  describe "voter connected" do
    
    before (:each) do
      @campaign = Factory(:campaign)
      caller_session = Factory(:caller_session)
      moderator_event = ModeratorCampaign.new(@campaign.id, 5, 2, 3, 2, 7, 3)
      @dummy_class.voter_connected(@campaign, caller_session)      
    end
    
    it "should increment callers on call" do
      ModeratorCampaign.on_call(@campaign.id).should eq(["3"])
    end
    
    it "should decrement callers on hold" do
      ModeratorCampaign.on_hold(@campaign.id).should eq(["1"])
    end

    it "should increment live lines" do
      ModeratorCampaign.live_lines(@campaign.id).should eq(["8"])
    end
    
    it "should decrement ringing lines" do
      ModeratorCampaign.ringing_lines(@campaign.id).should eq(["2"])
    end
        
  end
  
  describe "voter disconnected" do
    
    before (:each) do
      @campaign = Factory(:campaign)
      caller_session = Factory(:caller_session)
      moderator_event = ModeratorCampaign.new(@campaign.id, 5, 2, 3, 2, 7, 3)
      @dummy_class.voter_disconnected(@campaign, caller_session)      
    end
    
    it "should decrement callers on call" do
      ModeratorCampaign.on_call(@campaign.id).should eq(["1"])
    end
    
    it "should increment callers on wrapup" do
      ModeratorCampaign.wrapup(@campaign.id).should eq(["4"])
    end

    it "should decrement live lines" do
      ModeratorCampaign.live_lines(@campaign.id).should eq(["6"])
    end
    
  end
  
  describe "voter response submitted" do
    
    before (:each) do
      @campaign = Factory(:campaign)
      caller_session = Factory(:caller_session)
      moderator_event = ModeratorCampaign.new(@campaign.id, 5, 2, 3, 2, 7, 3)
      @dummy_class.voter_response_submitted(@campaign, caller_session)      
    end
    
    it "should decrement wrapup" do
      ModeratorCampaign.wrapup(@campaign.id).should eq(["2"])
    end
    
    it "should increment callers on hold" do
      ModeratorCampaign.on_hold(@campaign.id).should eq(["3"])
    end
    
  end
  
  describe "caller disconnected" do
    before (:each) do
      @campaign = Factory(:campaign)
      caller_session = Factory(:caller_session)
      moderator_event = ModeratorCampaign.new(@campaign.id, 5, 2, 3, 2, 7, 3)
      @dummy_class.caller_disconnected(@campaign, caller_session)      
    end
    
    it "should decrement callers logged in" do
      ModeratorCampaign.callers_logged_in(@campaign.id).should eq(["4"])
    end
    
  end
  
end