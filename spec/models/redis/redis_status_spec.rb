require 'rails_helper'

describe RedisStatus, :type => :model do
  let(:campaign){ create(:preview) }
  let(:caller_session) do
    create(:webui_caller_session, {
      campaign: campaign
    })
  end
  let(:status){ "On hold" }
  let(:caller_sessions) do
    create_list(:webui_caller_session, 5, {
      campaign: campaign
    })
  end

  it "should return back state and time" do
    Timecop.freeze do
      redis_status_set_state(campaign, status, caller_session)
      expect(RedisStatus.state_time(campaign.id, caller_session.id)).to eq([status, "00:00:00"])
    end
  end

  it "sends payload via ActiveSupport:subscriber" do
    payload = {
      campaign_id: campaign.id,
      caller_session_id: caller_session.id,
      status: status,
    }

    expect([
      RedisStatus,
      :set_state_changed_time,
      campaign,
      status,
      caller_session,
    ]).to instrument('call_flow.caller.state_changed').with(payload)
  end

  it "should delete state" do
    redis_status_set_state(campaign, status, caller_session)
    RedisStatus.delete_state(campaign.id,caller_session.id)
    expect(RedisStatus.state_time(campaign.id, caller_session.id)).to be_empty
  end

  describe 'count by status' do
    before do
      redis_status_set_state(campaign, status, caller_session)
      redis_status_set_state(campaign, "Wrap up", caller_sessions.first)
      redis_status_set_state(campaign, "On call", caller_sessions.second)
    end
    it "should return count by status" do
      caller_count_by_status = [1, 1, 1]
      expect(RedisStatus.count_by_status(campaign.id, [
        caller_session.id,
        caller_sessions.first.id,
        caller_sessions.second.id,
        4 # not active caller_session id.
      ])).to eq(caller_count_by_status)
    end

    it 'should not give bad arguments to hmget' do
      expect(RedisStatus.count_by_status(campaign.id, [])).to eq([0,0,0])
    end
  end

  describe 'on_hold_times' do
    def set_state(caller_session, state='On hold')
      redis_status_set_state(campaign, state, caller_session)
    end

    before do
      Timecop.freeze
      caller_sessions.unshift(caller_session)
      Timecop.travel(30.seconds.ago){ set_state(caller_sessions.first) }
      Timecop.travel(59.seconds.ago){ set_state(caller_sessions.second) }
      Timecop.travel(65.seconds.ago){ set_state(caller_sessions.third) }
      Timecop.travel(119.seconds.ago){ set_state(caller_sessions.fourth) }
      Timecop.travel(121.seconds.ago){ set_state(caller_sessions.fifth) }
      set_state(caller_sessions[5], 'On call')
    end

    after do
      caller_sessions.each do |caller_session|
        RedisStatus.delete_state(caller_session.campaign.id, caller_session.id)
      end
      Timecop.return
    end

    it 'returns a collection of times (rounded down to nearest minute) each caller has been in the "On hold" state' do
      caller_sessions_ids = caller_sessions.map(&:id)
      expect(RedisStatus.on_hold_times(campaign.id, *caller_sessions_ids)).to(eq([0, 0, 1, 1, 2]))
    end
  end
end
