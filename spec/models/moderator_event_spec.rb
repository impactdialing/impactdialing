require "spec_helper"

describe ModeratorEvent do
  
  before(:each) do
    @moderator_event = ModeratorEvent.new
    @campaign = Factory(:predictive)
    @caller_session = Factory(:caller_session)
    ModeratorCampaign.new(@campaign.id, 5, 2, 3, 2, 7, 3, 100, 200)
  end
  
  describe "incoming call" do                  
     it "should decrement ringing lines" do
       @moderator_event.incoming_call(@campaign)      
       ModeratorCampaign.ringing_lines(@campaign.id).should eq("2")
     end           
  end
  
  
  describe "voter connected" do
    
    before (:each) do
      @moderator_event.voter_connected(@campaign)      
    end
        
    it "should increment callers on call" do
      ModeratorCampaign.on_call(@campaign.id).should eq("3")
    end
    
    it "should decrement callers on hold" do
      ModeratorCampaign.on_hold(@campaign.id).should eq("1")
    end

    it "should increment live lines" do
      ModeratorCampaign.live_lines(@campaign.id).should eq("8")
    end
    
  end
  
  describe "voter disconnected" do

    before (:each) do
      @moderator_event.voter_disconnected(@campaign)      
    end
    
    it "should decrement callers on call" do
      ModeratorCampaign.on_call(@campaign.id).should eq("1")
    end
    
    it "should increment callers on wrapup" do
      ModeratorCampaign.wrapup(@campaign.id).should eq("4")
    end

    it "should decrement live lines" do
      ModeratorCampaign.live_lines(@campaign.id).should eq("6")
    end
    
  end
  
  describe "voter response submitted" do
    
    before (:each) do
      @moderator_event.voter_response_submitted(@campaign)      
    end
    
    it "should decrement wrapup" do
      ModeratorCampaign.wrapup(@campaign.id).should eq("2")
    end
    
    it "should increment callers on hold" do
      ModeratorCampaign.on_hold(@campaign.id).should eq("3")
    end
    
  end
  
  describe "caller disconnected" do
    
    before (:each) do
      @moderator_event.caller_disconnected(@campaign)      
    end    
    
    it "should decrement callers logged in" do
      ModeratorCampaign.callers_logged_in(@campaign.id).should eq("4")
    end
    
  end
  
end