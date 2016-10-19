require 'rails_helper'

describe 'CallFlow::Call::Dialed' do
  include ListHelpers

  let(:phone){ Forgery(:address).clean_phone }
  let(:caller_record){ create(:caller) }
  let(:caller_session) do
    create(:webui_caller_session, {
      campaign: campaign,
      sid: 'CA-caller-session-sid',
      on_call: true,
      caller: caller_record
    })
  end
  let(:twilio_params) do
    HashWithIndifferentAccess.new({
      'CallStatus'    => 'in-progress',
      'CallSid'       => 'CA123',
      'AccountSid'    => 'AC432',
      'campaign_id'   => campaign.id,
      'campaign_type' => campaign.type,
      'phone'         => phone
    })
  end

  describe '#collect_response(params, survey_response)' do
    let(:params) do
      {
        voter_id: 'lead-uuid'
      }
    end
    let(:survey_response) do
      {
        'id' => '42',
        'possible_response_id' => '41'
      }
    end
    let(:call_sid){ 'dialed-call-sid' }

    subject{ CallFlow::Call::Dialed.new(caller_record.telephony_provider_account_id, call_sid) }

    it 'saves the survey response' do
      subject.collect_response(params, survey_response)
      expect(subject.storage[:question_42]).to eq '41'
    end

    it 'saves params[:voter_id] as :lead_uuid' do
      subject.collect_response(params, survey_response)
      expect(subject.storage[:lead_uuid]).to eq 'lead-uuid'
    end
  end

  describe '#dispositioned(params)' do
    let(:campaign){ create(:predictive) }
    let(:voter_list){ create(:voter_list, campaign: campaign) }
    let(:phone){ Forgery(:address).clean_phone }
    let(:lead){ build_lead_hash(voter_list, phone) }
    let(:browser_params) do
      HashWithIndifferentAccess.new({
        'call_sid' => twilio_params[:CallSid],
        'lead' => {
          id: lead[:uuid]
        }.merge(lead),
        'question' => {
          '42' => "123",
          '43' => "128",
          '44' => "136"
        },
        'notes' => {
          'Suggestions' => 'Would like bouncier material.'
        },
        'stop_calling' => false
      })
    end

    subject{ CallFlow::Call::Dialed.new(caller_record.telephony_provider_account_id, browser_params['call_sid']) }

    let(:call_flow_caller_session) do
      double('CallFlow::CallerSession', {
        redirect_to_hold: nil,
        is_phones_only?: false
      })
    end

    before do
      subject.caller_session_sid = caller_session.sid
      allow(CallFlow::CallerSession).to receive(:new).with(caller_record.telephony_provider_account_id, caller_session.sid){ call_flow_caller_session }
    end

    it 'saves :mapped_status as CallAttempt::Status::SUCCESS' do
      subject.dispositioned(browser_params)
      expect(subject.storage[:mapped_status]).to eq CallAttempt::Status::SUCCESS
    end

    it 'saves params[:question] as JSON eg {question_id: selected_response_id,...}' do
      subject.dispositioned(browser_params)
      expect(subject.storage['questions']).to eq browser_params['question'].to_json
    end

    it 'saves params[:notes] as JSON eg {note_id: entered text,...}' do
      subject.dispositioned(browser_params)
      expect(subject.storage['notes']).to eq browser_params['notes'].to_json
    end

    it 'saves params[:lead] as JSON eg {phone: 123...,first_name: "John",...}' do
      subject.dispositioned(browser_params)
      expect(subject.storage['lead_uuid']).to eq browser_params['lead']['id']
    end

    context 'params[:stop_calling] is false' do
      it 'tells CallFlow::CallerSession instance to :redirect_to_hold' do
        expect(call_flow_caller_session).to receive(:redirect_to_hold)
        subject.dispositioned(browser_params)
      end
    end

    context 'params[:stop_calling] is true' do
      before do
        browser_params.merge!({stop_calling: true})
      end
      it 'tells CallFlow::CallerSession instance to :stop_calling' do
        expect(call_flow_caller_session).to receive(:stop_calling)
        subject.dispositioned(browser_params)
      end
    end

    context 'caller is phones only' do
      before do
        allow(call_flow_caller_session).to receive(:is_phones_only?){ true }
        allow(subject).to receive(:caller_session){ caller_session }
        expect(call_flow_caller_session).to_not receive(:redirect_to_hold)
        expect(call_flow_caller_session).to_not receive(:stop_calling)
      end

      it 'does not redirect_to_hold' do
        subject.dispositioned(browser_params)
      end

      it 'does not stop_calling' do
        subject.dispositioned(browser_params.merge(stop_calling: true))
      end
    end
  end

  describe '#manual_message_dropped' do
    let(:campaign){ create(:power) }
    let(:recording){ create(:recording, account: campaign.account) }

    subject{ CallFlow::Call::Dialed.new(twilio_params[:AccountSid], twilio_params[:CallSid]) }

    before do
      subject.caller_session_sid = caller_session.sid
      campaign.update_attribute(:recording_id, recording.id)
    end

    it 'records that a manual message was dropped' do
      subject.manual_message_dropped(recording)
      expect(subject.storage['mapped_status']).to eq CallAttempt::Status::VOICEMAIL
      expect(subject.storage['recording_id']).to eq recording.id.to_s
      expect(subject.storage['recording_delivered_manually']).to eq '1'
    end

    it 'queues CallerPusherJob with "message_drop_success"' do
      subject.manual_message_dropped(recording)
      expect([:sidekiq, :call_flow]).to have_queued(CallerPusherJob).with(caller_session.id, 'publish_message_drop_success', 1, {})
    end
  end

  describe '#completed' do
    let(:campaign){ create(:predictive) }
    let(:status_callback_params) do
      twilio_params.merge(HashWithIndifferentAccess.new({
        'CallDuration'      => 120,
        'RecordingUrl'      => 'http://recordings.twilio.com/yep.mp3',
        'RecordingSid'      => 'RE-341',
        'RecordingDuration' => 119
      }))
    end

    subject{ CallFlow::Call::Dialed.new(status_callback_params[:AccountSid], status_callback_params[:CallSid]) }

    before do
      subject.caller_session_sid = caller_session.sid
    end

    it 'queues CallerPusherJob for call_ended' do
      subject.completed(campaign, status_callback_params)
      expect([:sidekiq, :call_flow]).to have_queued(CallerPusherJob).with(caller_session.id, 'publish_call_ended', 1, status_callback_params)
    end

    it 'updates storage with twilio params' do
      subject.completed(campaign, status_callback_params)
      status_callback_params.each do |key,value|
        key = key.underscore.gsub('call_','')
        expect(subject.storage[key]).to eq value.to_s
      end
    end

    shared_examples_for 'calls not answered' do
      it 'tells campaign :number_not_ringing' do
        expect(campaign).to receive(:number_not_ringing)
        subject.completed(campaign, status_callback_params)
      end

      context 'dial mode is Preview' do
        let(:campaign){ create(:preview) }
        it 'redirects the caller to the next call' do
          subject.completed(campaign, status_callback_params)
          # expect([:sidekiq, :call_flow]).to have_queued(RedirectCallerJob).with(caller_session.id)
        end
      end

      context 'dial mode is Power' do
        let(:campaign){ create(:power) }
        it 'redirects the caller to the next call' do
          subject.completed(campaign, status_callback_params)
          # expect([:sidekiq, :call_flow]).to have_queued(RedirectCallerJob).with(caller_session.id)
        end
      end

      context 'dial mode is Predictive' do
        it 'does not redirect the caller' do
          subject.completed(campaign, status_callback_params)
          # expect([:sidekiq, :call_flow]).to_not have_queued(RedirectCallerJob)
        end
      end
    end

    context '#caller_session_call is nil' do
      # can be the case when caller & lead disconnect at same time
      before do
        allow(CallFlow::CallerSession).to receive(:new){ nil }
      end

      it 'does not raise exception' do
        expect{
          subject.completed(campaign, status_callback_params)
        }.to_not raise_error
      end
    end

    context 'CallStatus is completed' do
      before do
        status_callback_params['CallStatus'] = 'completed'
      end

      context 'and not answered' do
        it_behaves_like 'calls not answered'
      end

      context 'and answered but not connected' do
        it 'queues persistence job' do
          subject.completed(campaign, status_callback_params)
          expect([:sidekiq, :persistence]).to have_queued(CallFlow::Jobs::Persistence).with('Completed', twilio_params[:AccountSid], twilio_params[:CallSid])
        end
      end
    end

    context 'CallStatus is failed' do
      before do
        status_callback_params['CallStatus'] = 'failed'
      end

      it_behaves_like 'calls not answered'

      it 'tells CallFlow::Call::Failed to create an entry' do
        expect(CallFlow::Call::Failed).to receive(:create).with(campaign, status_callback_params['phone'], status_callback_params, false)
        subject.completed(campaign, status_callback_params)
      end
    end
  end

  describe '#disconnected(caller_session, params)' do
    let(:campaign){ create(:predictive) }
    let(:disconnected_params) do
      twilio_params.merge({
        RecordingUrl: 'http://recordings.twilio.com/yep.mp3',
        RecordingSid: 'RE-321'
      })
    end
    subject{ CallFlow::Call::Dialed.new(twilio_params[:AccountSid], twilio_params[:CallSid]) }

    before do
      subject.caller_session_sid = caller_session.sid
      subject.caller_session_call.dialed_call_sid = disconnected_params[:CallSid]
      expect(subject.caller_session_call.dialed_call_sid).to eq disconnected_params[:CallSid]
      subject.disconnected(campaign, disconnected_params)
    end

    xit 'queues CallerPusherJob for voter_disconnected' do
      expect([:sidekiq, :call_flow]).to have_queued(CallerPusherJob).with(caller_session.id, 'publish_voter_disconnected', 1, {})
    end

    xit 'updates RedisStatus for caller session to "Wrap up"' do
      expect(RedisStatus.state_time(campaign.id, caller_session.id).first).to eq 'Wrap up'
    end

    it 'updates storage with twilio params' do
      disconnected_params.each do |key,value|
        key = key.underscore.gsub('call_','')
        expect(subject.storage[key]).to eq value.to_s
      end
    end
  end

  describe '#answered(campaign, twilio_params)' do
    let(:rest_response) do
      HashWithIndifferentAccess.new({
        'status'      => 'queued',
        'sid'         => 'CA123',
        'account_sid' => 'AC432'
      })
    end
    let(:twilio_callback_params) do
      {
        host: Settings.twilio_callback_host,
        port: Settings.twilio_callback_port,
        protocol: 'http://'
      }
    end

    subject{ CallFlow::Call::Dialed.create(campaign, rest_response, {caller_session_sid: caller_session.sid}) }

    shared_context 'answering machine setup' do
      let(:machine_twilio_params){ twilio_params.merge('AnsweredBy' => 'machine') }

      before do
        recording = create(:recording)
        campaign.update_attributes!(recording_id: recording.id)
        expect(campaign.reload.recording).to eq recording
        subject.answered(campaign, machine_twilio_params)
      end
    end

    shared_examples_for 'answered call of any dialing mode' do
      it 'updates state history to record that :answered was visited' do
        RedisStatus.set_state_changed_time(campaign.id, 'On hold', caller_session.id)
        subject.answered(campaign, twilio_params)
        expect(subject.state_visited?(:answered)).to be_truthy
      end

      it 'tells campaign :number_not_ringing' do
        RedisStatus.set_state_changed_time(campaign.id, 'On hold', caller_session.id)
        expect(campaign).to receive(:number_not_ringing)
        subject.answered(campaign, twilio_params)
      end

      it 'updates storage with twilio params' do
        RedisStatus.set_state_changed_time(campaign.id, 'On hold', caller_session.id)
        subject.answered(campaign, twilio_params)

        expect(subject.storage['campaign_id'].to_i).to eq campaign.id
        expect(subject.storage['campaign_type']).to eq campaign.type
        expect(subject.storage['status']).to eq twilio_params['CallStatus']
      end

      it 'sets :dialed_call_sid on caller_session_call' do
        RedisStatus.set_state_changed_time(campaign.id, 'On hold', caller_session.id)
        subject.answered(campaign, twilio_params)
        expect(subject.caller_session_call.dialed_call_sid).to eq rest_response['sid']
      end

      context 'when call is answered by human and CallStatus == "in-progress"' do
        context 'when caller is still connected' do
          before do
            RedisStatus.set_state_changed_time(campaign.id, 'On hold', caller_session.id)
            campaign.account.update_attributes(record_calls: true)
          end

          it 'updates RedisStatus for caller session to On call' do
            subject.answered(campaign, twilio_params)
            status, time = RedisStatus.state_time(campaign.id, caller_session.id)
            expect(status).to eq 'On call'
          end
          it 'queues VoterConnectedPusherJob' do
            subject.answered(campaign, twilio_params)
            expect([:sidekiq, :call_flow]).to have_queued(VoterConnectedPusherJob).with(caller_session.id, twilio_params['CallSid'], phone)
          end
          it 'sets @record_calls = campaign.account.record_calls' do
            subject.answered(campaign, twilio_params)
            expect(subject.record_calls).to eq 'true'
          end
          it 'sets @twiml_flag = :connect' do
            subject.answered(campaign, twilio_params)
            expect(subject.twiml_flag).to eq :connect
          end
        end
        context 'caller has disconnected' do
          before do
            caller_session.update_attributes!({on_call: false})
          end
          it 'sets @twiml_flag = :hangup' do
            subject.answered(campaign, twilio_params)
            expect(subject.twiml_flag).to eq :hangup
          end
        end
        context 'caller is already talking to a lead' do
          before do
            RedisStatus.set_state_changed_time(campaign.id, 'On call', caller_session.id)
          end

          it 'sets @twiml_flag = :hangup' do
            subject.answered(campaign, twilio_params)
            expect(subject.twiml_flag).to eq :hangup
          end

          it 'sets #storage[:mapped_status] to CallAttempt::Status::ABANDONED' do
            subject.answered(campaign, twilio_params)
            expect(subject.storage[:mapped_status]).to eq CallAttempt::Status::ABANDONED
          end
        end
      end

      context 'when call is answered by machine' do
        include_context 'answering machine setup'
        context 'when campaign drops message on machine' do
          let(:answering_machine_agent){ double('AnsweringMachineAgent', {leave_message?: true, record_message_drop: nil}) }

          before do
            allow(AnsweringMachineAgent).to receive(:new){ answering_machine_agent }
          end

          context 'and this is first message drop' do
            it 'records that a message was left for this phone' do
              expect(answering_machine_agent).to receive(:record_message_drop)
              subject.answered(campaign, machine_twilio_params)
            end
            it 'sets @twiml_flag = :leave_message' do
              subject.answered(campaign, machine_twilio_params)
              expect(subject.twiml_flag).to eq :leave_message
            end
          end
          context 'and this is not first dial for phone' do
            before do
              allow(answering_machine_agent).to receive(:leave_message?){ false }
            end
            it 'sets @twiml_flag = :hangup' do
              subject.answered(campaign, machine_twilio_params)
              expect(subject.twiml_flag).to eq :hangup
            end
          end
        end
      end
    end

    shared_examples_for 'Preview or Power dial modes' do
      context 'when answered by machine' do
        include_context 'answering machine setup'
        it 'redirects the caller, moving them on to next dial' do
          expect([:sidekiq, :call_flow]).to have_queued(RedirectCallerJob).with(caller_session.id)
        end
      end
    end

    context 'Preview dial mode' do
      let(:campaign){ create(:preview) }
      let(:phone){ Forgery(:address).clean_phone }

      it_behaves_like 'answered call of any dialing mode'
      it_behaves_like 'Preview or Power dial modes'
    end

    context 'Power dial mode' do
      let(:campaign){ create(:power) }
      let(:phone){ Forgery(:address).clean_phone }
      
      it_behaves_like 'answered call of any dialing mode'
      it_behaves_like 'Preview or Power dial modes'
    end

    context 'Predictive dial mode' do
      let(:campaign){ create(:predictive) }
      let(:phone){ Forgery(:address).clean_phone }

      before do
        RedisOnHoldCaller.add(campaign.id, caller_session.id)
      end

      it_behaves_like 'answered call of any dialing mode'
    end
  end

  describe '.create(campaign, rest_response)' do
    subject{ CallFlow::Call::Dialed }

    let(:rest_response) do
      {
        'account_sid' => 'AC-123',
        'sid' => 'CA-3212',
        'status' => 'queued',
        'to' => '1234568890',
        'from' => '8890654321'
      }
    end
    let(:dialed_call){ subject.new(rest_response['account_sid'], rest_response['sid']) }

    context 'campaign is new or is not Preview, Power or Predictive' do
      let(:not_campaign) do
        Campaign.new
      end

      it 'raises ArgumentError' do
        expect{
          subject.create(not_campaign, rest_response)
        }.to raise_error(ArgumentError, "CallFlow::Call::Dialed received new or unknown campaign: #{not_campaign.class}")
      end
    end

    context 'campaign is Preview or Power' do
      let(:campaign){ create(:preview) }
      let(:inflight_stats){ Twillio::InflightStats.new(campaign) }
      let(:optional_properties) do
        {
          'caller_session_sid' => 'CA-cs123'
        }
      end

      before do
        expect(inflight_stats.get('presented')).to be_zero
        subject.create(campaign, rest_response, optional_properties)
      end

      it 'increments "ringing" count for campaign by 1' do
        expect(inflight_stats.get('ringing')).to eq 1
      end
      it 'does not decrement "presented" count for campaign' do
        expect(inflight_stats.get('presented')).to be_zero
      end
      it 'saves rest_response to attached storage instance' do
        rest_response.each do |property,value|
          expect(dialed_call.storage[property]).to eq value
        end
      end
      it 'saves caller_session_id to attached storage instance' do
        expect(dialed_call.caller_session_sid).to eq optional_properties['caller_session_sid']
      end
    end

    context 'campaign is Predictive' do
      let(:campaign){ create(:predictive) }
      let(:inflight_stats){ Twillio::InflightStats.new(campaign) }

      before do
        inflight_stats.incby 'presented', 1
        subject.create(campaign, rest_response, {})
      end

      it 'increments "ringing" count for campaign by 1' do
        expect(inflight_stats.get('ringing')).to eq 1
      end
      it 'decrements "presented" count for campaign by 1' do
        expect(inflight_stats.get('presented')).to eq 0
      end
      it 'saves rest_response' do
        rest_response.each do |property,value|
          expect(dialed_call.storage[property]).to eq value
        end
      end
    end
  end
end

