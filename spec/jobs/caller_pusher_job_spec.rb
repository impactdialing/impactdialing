require "spec_helper"

describe CallerPusherJob do
  describe '.perform(caller_session_id, event)' do
    let(:caller_session) do
      create(:caller_session, caller: create(:caller))
    end
    before do
      expect(CallerSession).to receive(:find).and_return(caller_session)
    end
    it 'should send event' do
      expect(caller_session).to receive(:publish_voter_disconnected)
      job = CallerPusherJob.new
      job.perform(caller_session.id, "publish_voter_disconnected")
    end

    it 're-queues itself when CallFlow::DialQueue::Available::RedisTransactionAborted is raised' do
      event = 'publish_caller_conference_started'
      expect(caller_session).to receive(:publish_caller_conference_started).and_raise(CallFlow::DialQueue::Available::RedisTransactionAborted)

      CallerPusherJob.new.perform(caller_session.id, event)
      
      queue    = Sidekiq::Queue.new('call_flow')
      job      = queue.first.item
      expected = {
        'queue' => 'call_flow',
        'class' => 'CallerPusherJob',
        'args' => [caller_session.id, event]
      }

      expected.keys.each do |key|
        expect(job[key]).to eq expected[key]
      end
    end
  end
end
