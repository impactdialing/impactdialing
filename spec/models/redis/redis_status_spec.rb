require 'rails_helper'

describe RedisStatus, :type => :model do
  
  it "should return back state and time" do
    RedisStatus.set_state_changed_time(1, "On hold", 1)
    expect(RedisStatus.state_time(1, 1)).to eq(["On hold", "00:00:00"])
  end
  
  it "should delete state" do
    RedisStatus.set_state_changed_time(1, "On hold", 1)
    RedisStatus.delete_state(1,1)
    expect(RedisStatus.state_time(1, 1)).to be_empty
  end
  
  describe 'count by status' do
    before do
      RedisStatus.set_state_changed_time(1, "On hold", 1)
      RedisStatus.set_state_changed_time(1, "Wrap up", 2)
      RedisStatus.set_state_changed_time(1, "On call", 3)
    end
    it "should return count by status" do
      expect(RedisStatus.count_by_status(1, [1,4,3,2])).to eq([1, 1, 1])
    end

    it 'should not give bad arguments to hmget' do
      expect(RedisStatus.count_by_status(1, [])).to eq([0,0,0])
    end
  end
  
  describe 'on_hold_times' do
    def set_state(caller_session_id, state='On hold')
      RedisStatus.set_state_changed_time(1, state, caller_session_id)
    end

    before do
      Timecop.travel(30.seconds.ago){ set_state(1) }
      Timecop.travel(59.seconds.ago){ set_state(2) }
      Timecop.travel(65.seconds.ago){ set_state(3) }
      Timecop.travel(119.seconds.ago){ set_state(4) }
      Timecop.travel(121.seconds.ago){ set_state(5) }
      set_state(6, 'On call')
    end

    after do
      5.times do |i|
        RedisStatus.delete_state(1, i + 1)
      end
    end

    it 'returns a collection of times (seconds) each caller has been in the "On hold" state' do
      expect(RedisStatus.on_hold_times(1, *(1..6).to_a)).to(eq([30, 59, 65, 119, 121]))
    end
  end
end
