require "spec_helper"

describe MonitorEvent do
  
  before(:each) do
    @campaign = Factory(:predictive)
    @caller_session = Factory(:caller_session)
    MonitorCampaign.new(@campaign.id, 5, 2, 3, 2, 7, 3, 100, 200)
  end
  
  describe "incoming call" do                  
     it "should decrement ringing lines" do
       MonitorEvent.incoming_call_request(@campaign)      
       MonitorCampaign.ringing_lines(@campaign.id).should eq("2")
     end           
  end
  
  
  describe "voter connected" do
    
    before (:each) do
      MonitorEvent.voter_connected(@campaign)      
    end
        
    it "should increment callers on call" do
      MonitorCampaign.on_call(@campaign.id).should eq("3")
    end
    
    it "should decrement callers on hold" do
      MonitorCampaign.on_hold(@campaign.id).should eq("1")
    end

    it "should increment live lines" do
      MonitorCampaign.live_lines(@campaign.id).should eq("8")
    end
    
  end
  
  describe "voter disconnected" do

    before (:each) do
      MonitorEvent.voter_disconnected(@campaign)      
    end
    
    it "should decrement callers on call" do
      MonitorCampaign.on_call(@campaign.id).should eq("1")
    end
    
    it "should increment callers on wrapup" do
      MonitorCampaign.wrapup(@campaign.id).should eq("4")
    end

    it "should decrement live lines" do
      MonitorCampaign.live_lines(@campaign.id).should eq("6")
    end
    
  end
  
  describe "voter response submitted" do
    
    before (:each) do
      MonitorEvent.voter_response_submitted(@campaign)      
    end
    
    it "should decrement wrapup" do
      MonitorCampaign.wrapup(@campaign.id).should eq("2")
    end
    
    it "should increment callers on hold" do
      MonitorCampaign.on_hold(@campaign.id).should eq("3")
    end
    
  end
  
  describe "caller disconnected" do
    
    before (:each) do
      MonitorEvent.caller_disconnected(@campaign)      
    end    
    
    it "should decrement callers logged in" do
      MonitorCampaign.callers_logged_in(@campaign.id).should eq("4")
    end
    
  end
  
end