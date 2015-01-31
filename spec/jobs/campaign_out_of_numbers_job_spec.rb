require 'spec_helper'

describe 'CampaignOutOfNumbersJob.perform(caller_session_id)' do
  let(:campaign){ create(:predictive) }
  let(:caller_session){ create(:webui_caller_session, campaign: campaign) }

  context 'the caller session is not available (ie the caller is on the line w/ a contact)' do
    before do
      caller_session.update_attributes!(on_call: true, available_for_call: false)
    end
    it 're-queues the job to run again after 1 minute' do
      CampaignOutOfNumbersJob.new.perform(caller_session.id)

      redis = Redis.new
      # sidekiq uses resque namespace
      scheduled_jobs = redis.zrange('resque:schedule', 0, -1).map{|job| JSON.load(job)}

      scheduled = scheduled_jobs.find do |job|
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
end