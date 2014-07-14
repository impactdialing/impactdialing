require "spec_helper"

describe RedisDataCentre, :type => :model do
  
  it "should set and retrive dc code as comma seperated values" do
    RedisDataCentre.set_datacentres_used(1, DataCentre::Code::ORL)
    RedisDataCentre.set_datacentres_used(1, DataCentre::Code::ATL)
    expect(RedisDataCentre.data_centres(1)).to eq("atl,orl")
  end
  
  it "should set give unique dcs" do
    RedisDataCentre.set_datacentres_used(1, DataCentre::Code::ORL)
    RedisDataCentre.set_datacentres_used(1, DataCentre::Code::ATL)
    RedisDataCentre.set_datacentres_used(1, DataCentre::Code::ORL)
    RedisDataCentre.set_datacentres_used(1, DataCentre::Code::ORL)
    RedisDataCentre.set_datacentres_used(1, DataCentre::Code::ATL)
    expect(RedisDataCentre.data_centres(1)).to eq("atl,orl")
  end
  
  
  it "should set and retrive dc code as empty if no codes set" do
    expect(RedisDataCentre.data_centres(2)).to eq("")
  end
  
end