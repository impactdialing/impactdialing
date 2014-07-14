require "spec_helper"

describe RedisOnHoldCaller, :type => :model do
  
  it "should add caller" do
    RedisOnHoldCaller.add(1, 1, DataCentre::Code::TWILIO)
    expect(RedisOnHoldCaller.longest_waiting_caller(1, DataCentre::Code::TWILIO)).to eq("1")
    expect(RedisOnHoldCaller.longest_waiting_caller(1, DataCentre::Code::TWILIO)).to eq(nil)
  end
  
  it "should remove caller" do
    RedisOnHoldCaller.add(1, 1, DataCentre::Code::TWILIO)
    RedisOnHoldCaller.remove_caller_session(1, 1, DataCentre::Code::TWILIO)
    expect(RedisOnHoldCaller.longest_waiting_caller(1, DataCentre::Code::TWILIO)).to eq(nil)
  end
  
  it "should add to bottom of list" do
    RedisOnHoldCaller.add(1, 1, DataCentre::Code::TWILIO)
    RedisOnHoldCaller.add_to_bottom(1, 2, DataCentre::Code::TWILIO)
    expect(RedisOnHoldCaller.longest_waiting_caller(1, DataCentre::Code::TWILIO)).to eq("2")
  end
end
