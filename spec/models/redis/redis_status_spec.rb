require "spec_helper"

describe RedisStatus, :type => :model do
  
  it "should return back state and time" do
    RedisStatus.set_state_changed_time(1, "On hold", 1)
    expect(RedisStatus.state_time(1, 1)).to eq(["On hold", "00:00:00"])
  end
  
  it "should delete state" do
    RedisStatus.set_state_changed_time(1, "On hold", 1)
    RedisStatus.delete_state(1,1)
    expect(RedisStatus.state_time(1, 1)).to be_nil
  end
  
  it "should return count by status" do
    RedisStatus.set_state_changed_time(1, "On hold", 1)
    RedisStatus.set_state_changed_time(1, "Wrap up", 2)
    RedisStatus.set_state_changed_time(1, "On call", 3)
    expect(RedisStatus.count_by_status(1, [1,4,3,2])).to eq([1, 1, 1])
  end
  
end
