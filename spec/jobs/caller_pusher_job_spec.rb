require 'rails_helper'

describe CallerPusherJob do
  describe '.perform(caller_session_id, event)' do
    let(:caller_session) do
      create(:caller_session, {
        caller: create(:caller),
        sid: 'caller-session-sid'
      })
    end
    let(:call_flow_events) do
      instance_double('CallFlow::Events', {
        completed?: false,
        completed: nil
      })
    end
    let(:event){ 'publish_caller_conference_started' }
    let(:sequence){ 12 }
    before do
      allow(CallFlow::Events).to receive(:new).with(caller_session.caller_session_call){ call_flow_events }
      allow(caller_session).to receive(event)
      allow(CallerSession).to receive(:find).and_return(caller_session)
    end

    subject{ CallerPusherJob.new }

    it 'should send event' do
      expect(caller_session).to receive(event)
      subject.perform(caller_session.id, event, sequence)
    end

    it 'should mark the event as completed' do
      expect(call_flow_events).to receive(:completed).with(sequence)
      subject.perform(caller_session.id, event, sequence)
    end

    it 'should not run a job when the event has already been sent' do
      allow(call_flow_events).to receive(:completed?){ true }
      expect(caller_session).to_not receive(event)
      subject.perform(caller_session.id, event, sequence)
    end

    it 're-queues itself when CallFlow::DialQueue::EmptyHousehold is raised' do
      expect(caller_session).to receive(:publish_caller_conference_started).and_raise(CallFlow::DialQueue::EmptyHousehold)

      subject.perform(caller_session.id, event, sequence)
      
      expect([:sidekiq, :call_flow]).to have_queued(CallerPusherJob).with(caller_session.id, event, sequence, {})
    end

    it 're-queues itself when CallFlow::DialQueue::MismatchedHousehold is raised' do
      expect(caller_session).to receive(:publish_caller_conference_started).and_raise(CallFlow::DialQueue::MismatchedHousehold)
      subject.perform(caller_session.id, event, sequence)
      expect([:sidekiq, :call_flow]).to have_queued(CallerPusherJob).with(caller_session.id, event, sequence, {})
    end
  end
end
