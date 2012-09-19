require "spec_helper"

describe RedisCampaignCall do
  
  it "should add to ringing" do
    RedisCampaignCall.add_to_ringing("1", "1")
    RedisCampaignCall.ringing("1").length.should eq(1)
  end
  
  it "should move call from ringing to inprogress" do
    RedisCampaignCall.add_to_ringing("1", "1")
    RedisCampaignCall.move_ringing_to_inprogress("1", "1")
    RedisCampaignCall.ringing("1").length.should eq(0)
    RedisCampaignCall.inprogress("1").length.should eq(1)
  end
  
  it "should move call from inprogress to wrapup" do
    RedisCampaignCall.add_to_ringing("1", "1")
    RedisCampaignCall.move_ringing_to_inprogress("1", "1")
    RedisCampaignCall.move_inprogress_to_wrapup("1", "1")
    RedisCampaignCall.ringing("1").length.should eq(0)
    RedisCampaignCall.inprogress("1").length.should eq(0)
    RedisCampaignCall.wrapup("1").length.should eq(1)
  end
  
  it "should move call from ringing to abandoned" do
    RedisCampaignCall.add_to_ringing("1", "1")
    RedisCampaignCall.move_ringing_to_abandoned("1", "1")
    RedisCampaignCall.ringing("1").length.should eq(0)
    RedisCampaignCall.abandoned("1").length.should eq(1)
  end

  it "should move call from ringing to completed" do
    RedisCampaignCall.add_to_ringing("1", "1")
    RedisCampaignCall.move_ringing_to_completed("1", "1")
    RedisCampaignCall.ringing("1").length.should eq(0)
    RedisCampaignCall.completed("1").length.should eq(1)
  end
  
  
  it "should move call from wrapup to completed" do
    RedisCampaignCall.add_to_ringing("1", "1")
    RedisCampaignCall.move_ringing_to_inprogress("1", "1")
    RedisCampaignCall.move_inprogress_to_wrapup("1", "1")
    RedisCampaignCall.move_wrapup_to_completed("1", "1")
    RedisCampaignCall.ringing("1").length.should eq(0)
    RedisCampaignCall.completed("1").length.should eq(1)
  end
  
  it "should give above average inprogress calls" do
    RedisCampaignCall.add_to_ringing("1", "1")
    RedisCampaignCall.move_ringing_to_inprogress("1", "1")
    
  end
  
  
end
