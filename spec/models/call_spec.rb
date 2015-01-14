require "spec_helper"

describe Call, :type => :model do
  include FakeCallData

  def incoming_call(params)
    RedisCall.set_request_params(call.id, params)
    unless campaign.predictive?
      caller_session.update_attributes!({available_for_call: false, on_call: true, attempt_in_progress: call_attempt})
    end
    campaign.number_presented(1)
    campaign.number_ringing
    call.incoming_call(params)
  end

  before do
    Redis.new.flushall
  end
  let(:account){ create(:account) }

  shared_context 'setup for calling' do
    let(:caller) do
      create(:caller, campaign: campaign, account: account)
    end
    let(:caller_session) do
      create(:bare_caller_session, :webui, :available, session_key: 'abc123', campaign: campaign, caller: caller)
    end
    let(:household) do
      create(:household, campaign: campaign, account: campaign.account)
    end
    let(:call_attempt) do
      create(:bare_call_attempt, campaign: campaign, household: household)
    end
    let(:call) do
      create(:call, call_attempt: call_attempt)
    end
  end

  describe 'incoming call' do
    shared_examples 'all connected incoming calls' do
      it 'subtracts 1 from campaign.ringing_count' do
        expect(campaign.ringing_count).to eq 0
      end

      it 'updates connecttime of CallAttempt' do
        expect(call_attempt.reload.connecttime).to be > 1.minute.ago
      end

      it 'updates RedisStatus for caller session to On call' do
        status, time = RedisStatus.state_time(campaign.id, caller_session.id)
        expect(status).to eq 'On call'
      end

      it 'queues VoterConnectedPusherJob' do
        queue        = Sidekiq::Queue.new('call_flow')
        job          = queue.first.item
        expected_job = {
          'queue' => 'call_flow',
          'class' => 'VoterConnectedPusherJob',
          'args' => [caller_session.id, call.id]
        }
        expected_job.keys.each do |key|
          expect(job[key]).to eq expected_job[key]
        end
      end

      it 'returns conference twiml for callee' do
        twiml = [
          "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
          "<Response><Dial hangupOnStar=\"false\" ",
          "action=\"http://#{Settings.twilio_callback_host}",
          "/calls/#{call.id}/disconnected\" ",
          "record=\"false\">",
          "<Conference waitUrl=\"hold_music\" waitMethod=\"GET\" ",
          "beep=\"false\" endConferenceOnExit=\"true\">",
          caller_session.session_key,
          "</Conference>",
          "</Dial></Response>"
        ]
        expect(@twiml).to eq(twiml.join)
      end
    end

    shared_examples 'all machine answered calls' do
      it 'adds call id to redis machine call storage' do
        time = RedisCallFlow.processing_by_machine_call_hash[call.id]
        expect(Time.parse(time)).to be > 1.minute.ago
      end

      context 'message drop disabled' do
        it 'returns hangup twiml' do
          twiml = [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<Response><Hangup/></Response>"
          ]
          expect(@twiml).to eq twiml.join
        end
      end

      context 'message drop enabled' do
        let(:recording){ create(:recording) }
        before do
          campaign.update_attributes!(use_recordings: true, answering_machine_detect: true, recording_id: recording.id)
          @twiml = incoming_call(params)
        end

        it 'stores recording id & "automatic" under call id in redis' do
          # binding.pry
          info = RedisCallFlow.get_message_drop_info(call.id)
          expect(info['recording_id']).to eq campaign.recording_id
          expect(info['drop_type']).to eq 'automatic'
        end

        it 'returns play message twiml' do
          twiml = [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<Response><Play>",
            "http://s3.amazonaws.com/impactdialing_production/test/uploads/unknown/#{recording.id}.mp3",
            "</Play><Hangup/></Response>"
          ]

          expect(@twiml).to eq twiml.join
        end
      end
    end

    context 'Preview/Power modes' do
      let(:campaign) do
        create_campaign_with_script(:bare_preview, account).last
      end
      let(:params) do
        {
          'answered_by' => 'human',
          'call_status' => 'in-progress'
        }
      end

      include_context 'setup for calling'

      describe 'human answers' do
        before do
          @twiml = incoming_call(params)
        end
        it_behaves_like 'all connected incoming calls'
      end

      describe 'machine answers' do
        let(:params) do
          {
            'answered_by' => 'machine',
            'call_status' => 'in-progress'
          }
        end
        before do
          @twiml = incoming_call(params)
        end

        it 'redirects the caller' do
          queue        = Sidekiq::Queue.new('call_flow')
          job          = queue.first.item
          expected_job = {
            'queue' => 'call_flow',
            'class' => 'RedirectCallerJob',
            'args' => [caller_session.id]
          }
          expected_job.keys.each do |key|
            expect(job[key]).to eq expected_job[key]
          end
        end

        it_behaves_like 'all machine answered calls'
      end
    end

    context 'Predictive mode' do
      let(:campaign) do
        create_campaign_with_script(:bare_predictive, account).last
      end
      let(:params) do
        {
          'answered_by' => 'human',
          'call_status' => 'in-progress'
        }
      end

      before do
        RedisOnHoldCaller.add(campaign.id, caller_session.id)
      end

      include_context 'setup for calling'

      describe 'human answers' do
        before do
          @twiml = incoming_call(params)
        end

        it_behaves_like 'all connected incoming calls'

        it 'updates CallerSession#attempt_in_progress w/ CallAttempt' do
          expect(caller_session.attempt_in_progress).to eq call_attempt
        end

        context 'when CallerSession is a stale object' do
          it 'retries a few times' do
            RedisOnHoldCaller.add(campaign.id, caller_session.id)
            allow(caller_session).to receive(:update_attributes).exactly(2).times{ raise ActiveRecord::StaleObjectError.new(caller_session, "Stale") }
            expect(CallerSession).to receive(:find_by_id_cached).exactly(3).times{ caller_session }
            allow(caller_session).to receive(:update_attributes).and_call_original
            incoming_call(params)
          end

          context 'when CallerSession is consistently stale' do
            before do
              RedisOnHoldCaller.add(campaign.id, caller_session.id)
              allow(Twillio).to receive(:set_attempt_in_progress){ raise ActiveRecord::StaleObjectError.new(caller_session, "Stale") }
              # RescueRetryNotify will send an email when retry threshold is exhausted
              VCR.use_cassette('Mandrill send email') do
                @twiml = incoming_call(params)
              end
            end
            it 'adds the caller session id back to RedisOnHoldCaller' do
              expect(RedisOnHoldCaller.longest_waiting_caller(campaign.id).to_i).to eq caller_session.id
            end

            it 'abandons the call' do
              twiml = [
                "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
                "<Response><Hangup/></Response>"
              ]
              info = RedisCallFlow.abandoned_call_list
              info = JSON.load(info.first)
              expect(info['id']).to eq call.id
              expect(Time.parse(info['current_time'])).to be > 1.minute.ago
              expect(@twiml).to eq twiml.join
            end
          end
        end
      end

      describe 'machine answers' do
        let(:params) do
          {
            'answered_by' => 'machine',
            'call_status' => 'in-progress'
          }
        end
        let(:recording) do
          create(:recording)
        end
        before do
          @twiml = incoming_call(params)
        end

        it_behaves_like 'all machine answered calls'

        it 'does not update CallerSession#attempt_in_progress w/ CallAttempt' do
          expect(caller_session.attempt_in_progress).to be_nil
        end
      end
    end
  end

  describe "initial" do
    describe "incoming call answered by human that need to be abandoned" do
      before(:each) do
        @caller = create(:caller)
        @script = create(:script)
        @campaign =  create(:predictive, script: @script)
        @voter  = create(:voter, campaign: @campaign, caller_session: @caller_session)
        @caller_session = create(:webui_caller_session, caller: @caller, campaign: @campaign, attempt_in_progress: @call_attempt)
        @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign, caller: @caller)
      end

      it "should return hangup twiml for abandoned users" do
        call = create(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'in-progress')
        RedisCall.set_request_params(call.id, call.attributes)
        expect(RedisCallFlow).to receive(:push_to_abandoned_call_list).with(call.id);
        # expect(@call_attempt).to receive(:redirect_caller) # 
        expect(call.incoming_call).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end
    end
  end

  describe "connected" do

    describe "hangup "  do
      before(:each) do
        @caller = create(:caller)
        @script = create(:script)
        @campaign =  create(:campaign, script: @script)
        @voter = create(:voter, campaign: @campaign)
        @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign, sid: "abc", caller: @caller)
      end

      it "should render nothing" do
        call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
        RedisCall.set_request_params(call.id, call.attributes)
        expect(@call_attempt).to receive(:enqueue_call_flow).with(EndRunningCallJob, [@call_attempt.sid])
        call.hungup
      end
    end

    describe "disconnect"  do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:campaign, script: @script)
        @caller = create(:caller)
        @caller_session = create(:caller_session, caller: @caller)
        @voter = create(:voter, campaign: @campaign, caller_session: @caller_session)
        @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session, caller: @caller)
      end

      it "should hangup twiml" do
        call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
        RedisCall.set_request_params(call.id, call.attributes)
        expect(RedisCallFlow).to receive(:push_to_disconnected_call_list).with(call.id, call.recording_duration, call.recording_url, @caller.id)
        expect(@call_attempt).to receive(:enqueue_call_flow).with(CallerPusherJob, [@caller_session.id, "publish_voter_disconnected"])
        expect(call.disconnected).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end
    end
  end

  describe "hungup" do

    describe "disconnect call" do
      before(:each) do
       @script = create(:script)
       @campaign =  create(:campaign, script: @script)
       @caller = create(:caller)
       @caller_session = create(:caller_session, caller: @caller)
       @voter = create(:voter, campaign: @campaign, caller_session: @caller_session)
       @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session, caller: @caller)
      end


      it "should hangup twiml" do
       call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'hungup')
       RedisCall.set_request_params(call.id, call.attributes)
       expect(RedisCallFlow).to receive(:push_to_disconnected_call_list).with(call.id, call.recording_duration, call.recording_url, @caller.id)
       expect(RedisStatus).to receive(:set_state_changed_time).with(@campaign.id, "Wrap up", @caller_session.id)
       expect(@call_attempt).to receive(:enqueue_call_flow).with(CallerPusherJob, [@caller_session.id, "publish_voter_disconnected"])
       expect(call.disconnected).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end
    end
  end

  describe "call_answered_by_lead" do
    describe "submit_result" do
      before(:each) do
        @caller = create(:caller)
        @script = create(:script)
        @campaign =  create(:campaign, script: @script)
        @voter = create(:voter, campaign: @campaign)
        @caller_session = create(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session, caller: @caller)
      end

      it "should wrap up and continue" do
        call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected')
        RedisCall.set_request_params(call.id, call.attributes)
        expect(RedisCallFlow).to receive(:push_to_wrapped_up_call_list).with(@call_attempt.id, CallerSession::CallerType::TWILIO_CLIENT, @voter.id)
        expect(@call_attempt).to receive(:redirect_caller)
        expect(RedisStatus).to receive(:set_state_changed_time).with(@campaign.id, "On hold", @caller_session.id)
        call.wrapup_and_continue({voter_id: @voter.id})
      end
    end

    describe "submit_result_and_stop" do
      before(:each) do
        @caller = create(:caller)
        @script = create(:script)
        @campaign =  create(:campaign, script: @script)
        @voter = create(:voter, campaign: @campaign)
        @caller_session = create(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session, caller: @caller)
      end

      it "should wrapup and stop" do
        call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected')
        RedisCall.set_request_params(call.id, call.attributes)
        expect(RedisCallFlow).to receive(:push_to_wrapped_up_call_list).with(@call_attempt.id, CallerSession::CallerType::TWILIO_CLIENT, @voter.id)
        expect(@call_attempt).to receive(:end_caller_session)
        call.wrapup_and_stop({voter_id: @voter.id})
      end
    end
  end

  describe "state machine methods" do
    it "should return answered by machine" do
      call = create(:call, answered_by: "machine", call_attempt: @call_attempt, state: 'disconnected')
      RedisCall.set_request_params(call.id, call.attributes)
      expect(call.answered_by_machine?).to be_truthy
    end

    it "should return answered by human" do
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected')
      RedisCall.set_request_params(call.id, call.attributes)
      expect(call.answered_by_human?).to be_truthy
    end

    describe "answered_by_human_and_caller_available?" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:campaign, script: @script)
        @voter = create(:voter, campaign: @campaign)
        @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session)
        @caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, attempt_in_progress: @call_attempt, state: "connected")
      end

      it "should return answered_by_human_and_caller_available?" do
        call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
        RedisCall.set_request_params(call.id, call.attributes)
        expect(call.answered_by_human_and_caller_available?).to be_truthy
      end

      it "should return false if not answered by human" do
        call = create(:call, answered_by: "machine", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
        RedisCall.set_request_params(call.id, call.attributes)
        expect(call.answered_by_human_and_caller_available?).to be_falsey
      end

      it "should return false if call status is not in progress" do
        call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "completed")
        RedisCall.set_request_params(call.id, call.attributes)
        expect(call.answered_by_human_and_caller_available?).to be_falsey
      end

      it "should return false if caller session is nil" do
        @caller_session.update_attributes(attempt_in_progress: nil)
        call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
        RedisCall.set_request_params(call.id, call.attributes)
        expect(call.answered_by_human_and_caller_available?).to be_falsey
      end

      it "should return false if caller session is not available" do
        @caller_session.update_attributes(on_call: false)
        call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
        RedisCall.set_request_params(call.id, call.attributes)
        expect(call.answered_by_human_and_caller_available?).to be_falsey
      end

      it "should return true if caller session is nil" do
        @caller_session.update_attributes(attempt_in_progress: nil)
        call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
        RedisCall.set_request_params(call.id, call.attributes)
        expect(call.answered_by_human_and_caller_not_available?).to be_truthy
      end

      it "should return true if caller session is not available" do
        @caller_session.update_attributes(on_call: true, available_for_call: true)
        call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
        RedisCall.set_request_params(call.id, call.attributes)
        expect(call.answered_by_human_and_caller_not_available?).to be_truthy
      end
    end
  end

  describe "call did not connect" do
    it "should return true if busy" do
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "busy")
      RedisCall.set_request_params(call.id, call.attributes)
      expect(call.call_did_not_connect?).to be_truthy
    end

    it "should return true if no answer" do
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "no-answer")
      RedisCall.set_request_params(call.id, call.attributes)
      expect(call.call_did_not_connect?).to be_truthy
    end

    it "should return true if failed" do
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "failed")
      RedisCall.set_request_params(call.id, call.attributes)
      expect(call.call_did_not_connect?).to be_truthy
    end

    it "should return false if completed" do
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "completed")
      RedisCall.set_request_params(call.id, call.attributes)
      expect(call.call_did_not_connect?).to be_falsey
    end
  end

  describe "call_ended" do
    before(:each) do
      @caller = create(:caller)
      @script = create(:script)
      @campaign =  create(:predictive, script: @script)
      @voter  = create(:voter, campaign: @campaign)
      @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign)
      @caller_session = create(:webui_caller_session, caller: @caller, campaign: @campaign, attempt_in_progress: @call_attempt, on_call: true, available_for_call: false, state: "connected", sid: "123456")
      @call_attempt.caller_session = @caller_session
      @call_attempt.save!
    end

    it "should push to not connected call list if call did not connect" do
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "busy")
      RedisCall.set_request_params(call.id, call.attributes)
      expect(RedisCallFlow).to receive(:push_to_not_answered_call_list).with(call.id, "busy")
      call.call_ended("Preview")
    end

    it "should push to end by machine call list if answered by machine" do
      call = create(:call, answered_by: "machine", call_attempt: @call_attempt, state: 'initial', call_status: "busy")
      RedisCall.set_request_params(call.id, call.attributes)
      expect(RedisCallFlow).to receive(:push_to_end_by_machine_call_list).with(call.id)
      expect(call.call_ended("Preview")).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    end
  end
end

# ## Schema Information
#
# Table name: `calls`
#
# ### Columns
#
# Name                      | Type               | Attributes
# ------------------------- | ------------------ | ---------------------------
# **`id`**                  | `integer`          | `not null, primary key`
# **`call_attempt_id`**     | `integer`          |
# **`state`**               | `string(255)`      |
# **`call_sid`**            | `string(255)`      |
# **`call_status`**         | `string(255)`      |
# **`answered_by`**         | `string(255)`      |
# **`recording_duration`**  | `integer`          |
# **`recording_url`**       | `string(255)`      |
# **`created_at`**          | `datetime`         |
# **`updated_at`**          | `datetime`         |
# **`questions`**           | `text`             |
# **`notes`**               | `text`             |
# **`all_states`**          | `text`             |
#
