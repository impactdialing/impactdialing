require 'rails_helper'

describe 'CampaignOutOfNumbersJob.perform(caller_session_id)' do
  let(:campaign){ create(:predictive) }
  let(:caller_session){ create(:webui_caller_session, campaign: campaign) }
  let(:caller_session_call) do
    instance_double('CallFlow::CallerSession', {
      in_conversation?: false
    })
  end

  before do
    allow(caller_session).to receive(:caller_session_call){ caller_session_call }
    allow(CallerSession).to receive(:find).with(caller_session.id){ caller_session }
  end

  def resque_scheduled_jobs
    redis.zrange('resque:schedule', 0, -1).map{|job| JSON.parse(job)}
  end

  context 'the caller session is not available (ie the caller is on the line w/ a contact)' do
    before do
      allow(caller_session_call).to receive(:in_conversation?){ true }
      caller_session.update_attributes!(on_call: true)
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
      caller_session.update_attributes!(on_call: true)
    end
    it 'redirects the caller to the out of numbers message' do
      expect(Providers::Phone::Call).to receive(:redirect_for).with(caller_session, :out_of_numbers)
      CampaignOutOfNumbersJob.new.perform(caller_session.id)
    end
  end

  context 'the caller session is not on call (ie the caller has disconnected)' do
    it 'does not re-queue the job' do
      CampaignOutOfNumbersJob.new.perform(caller_session.id)
      expect(resque_scheduled_jobs).to be_empty
    end
  end
end
