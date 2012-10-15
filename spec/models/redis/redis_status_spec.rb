require "spec_helper"

describe RedisStatus do
  
  it "should return back state and time" do
    RedisStatus.set_state_changed_time(1, "On hold", 1)
    RedisStatus.state_time(1, 1).should eq([])
  end
  
end
