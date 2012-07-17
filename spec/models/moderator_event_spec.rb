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
    
  end
end