require "spec_helper"

describe RedisStartTime do
  
  it "should give time in state" do
    RedisStartTime.set_state_changed_time(1)
    RedisStartTime.time_in_state(1).should eq("")
  end
end
