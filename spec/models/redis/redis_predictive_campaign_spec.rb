require "spec_helper"

describe RedisPredictiveCampaign do
  
  it "should set and retrive dc code as comma seperated values" do
    RedisPredictiveCampaign.set_datacentres_used(1, DataCentre::Code::ORL)
    RedisPredictiveCampaign.set_datacentres_used(1, DataCentre::Code::ATL)
    RedisPredictiveCampaign.data_centres(1).should eq("atl,orl")
  end
  
  it "should set and retrive dc code as empty if no codes set" do
    RedisPredictiveCampaign.data_centres(2).should eq("")
  end
  
end