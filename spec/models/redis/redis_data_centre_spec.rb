require "spec_helper"

describe RedisDataCentre do
  
  it "should set and retrive dc code as comma seperated values" do
    RedisDataCentre.set_datacentres_used(1, DataCentre::Code::ORL)
    RedisDataCentre.set_datacentres_used(1, DataCentre::Code::ATL)
    RedisDataCentre.data_centres(1).should eq("atl,orl")
  end
  
  it "should set give unique dcs" do
    RedisDataCentre.set_datacentres_used(1, DataCentre::Code::ORL)
    RedisDataCentre.set_datacentres_used(1, DataCentre::Code::ATL)
    RedisDataCentre.set_datacentres_used(1, DataCentre::Code::ORL)
    RedisDataCentre.set_datacentres_used(1, DataCentre::Code::ORL)
    RedisDataCentre.set_datacentres_used(1, DataCentre::Code::ATL)
    RedisDataCentre.data_centres(1).should eq("atl,orl")
  end
  
  
  it "should set and retrive dc code as empty if no codes set" do
    RedisDataCentre.data_centres(2).should eq("")
  end
  
end