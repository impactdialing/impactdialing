require 'spec_helper'

describe 'CampaignOutOfNumbersJob.perform(caller_session_id)' do
  let(:campaign){ create(:predictive) }
  let(:caller_session){ create(:webui_caller_session, campaign: campaign) }

  def resque_scheduled_jobs
    redis          = Redis.new
    redis.zrange('resque:schedule', 0, -1).map{|job| JSON.load(job)}
  end

  def clear_resque_schedule
    redis          = Redis.new
    redis.zrem 'resque:schedule', redis.zrange('resque:schedule', 0, -1)
  end

  context 'the caller session is not available (ie the caller is on the line w/ a contact)' do
    before do
      caller_session.update_attributes!(on_call: true, available_for_call: false)
    end
    it 're-queues the job to run again after 1 minute' do
      CampaignOutOfNumbersJob.new.perform(caller_session.id)

      scheduled = resque_scheduled_jobs.find do |job|
        job['queue'] == 'call_flow' and
        job['class'] == 'CampaignOutOfNumbersJob' and
        job['args'] == [caller_session.id]
      end
      expect(scheduled).to be_present
    end
  end

  context 'the caller session is available (ie the caller is on hold)' do
    before do
      caller_session.update_attributes!(on_call: true, available_for_call: true)
    end
    it 'redirects the caller to the out of numbers message' do
      expect(Providers::Phone::Call).to receive(:redirect_for).with(caller_session, :out_of_numbers)
      CampaignOutOfNumbersJob.new.perform(caller_session.id)
    end
  end

  context 'the caller session is not on call (ie the caller has disconnected)' do
    it 'does not re-queue the job' do
      clear_resque_schedule
      CampaignOutOfNumbersJob.new.perform(caller_session.id)
      expect(resque_scheduled_jobs).to be_empty
    end
  end
end
