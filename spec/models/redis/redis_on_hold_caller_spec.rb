require 'rails_helper'

describe RedisOnHoldCaller, :type => :model do
  let(:campaign_id){ 1 }
  let(:caller_session_id){ 1 }
  let(:caller_session_id_two){ 2 }

  before do
    RedisOnHoldCaller.add(campaign_id, caller_session_id)
  end
  
  it "should add caller" do
    expect(RedisOnHoldCaller.longest_waiting_caller(1)).to eq("1")
    expect(RedisOnHoldCaller.longest_waiting_caller(1)).to eq(nil)
  end
  
  it "should remove caller" do
    RedisOnHoldCaller.remove_caller_session(campaign_id, caller_session_id)
    expect(RedisOnHoldCaller.longest_waiting_caller(1)).to eq(nil)
  end
  
  it "should add to bottom of list" do
    RedisOnHoldCaller.add_to_bottom(campaign_id, caller_session_id_two)
    expect(RedisOnHoldCaller.longest_waiting_caller(campaign_id)).to eq(caller_session_id_two.to_s)
  end
end
