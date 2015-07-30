require 'rails_helper'

describe Twiml::LeadController do
  after do
    Redis.new.flushall
  end

  describe '#answered (Preview/Power)' do
    let(:twilio_params) do
      {
        'CallStatus'    => 'in-progress',
        'CallSid'       => 'CA123',
        'AccountSid'    => 'AC432',
        'campaign_id'   => campaign.id,
        'campaign_type' => campaign.type,
        format: :xml
      }
    end
    let(:rest_response) do
      {
        'status'      => 'in-progress',
        'sid'         => 'CA123',
        'account_sid' => 'AC432'
      }
    end
    let(:caller_session) do
      create(:webui_caller_session, {
        campaign: campaign,
        sid: 'CA-caller-session-sid',
        on_call: true,
        available_for_call: false
      })
    end
    let(:dialed_call){ CallFlow::Call::Dialed.create(campaign, rest_response, {caller_session_sid: caller_session.sid}) }
    let(:twilio_callback_params) do
      {
        host: Settings.twilio_callback_host,
        port: Settings.twilio_callback_port,
        protocol: 'http://'
      }
    end

    before do
      dialed_call.caller_session_sid = caller_session.sid
    end

    shared_context 'answering machine setup' do
      let(:machine_twilio_params){ twilio_params.merge('AnsweredBy' => 'machine') }

      before do
        recording = create(:recording)
        campaign.update_attributes!(recording_id: recording.id)
        expect(campaign.reload.recording).to eq recording
        post :answered, machine_twilio_params
      end
    end

    shared_examples_for 'answered call of any dialing mode' do
      it 'updates history of CallFlow::Call::Dialed to record that :answered was visited' do
        post :answered, twilio_params

        live_call = CallFlow::Call::Dialed.new('AC432', 'CA123')
        expect(live_call.state_visited?(:answered)).to be_truthy
      end

      it 'loads @campaign' do
        post :answered, twilio_params
        expect(assigns[:campaign]).to eq campaign
      end

      it 'loads @caller_session' do
        post :answered, twilio_params
        expect(assigns[:caller_session]).to eq caller_session
      end

      it 'renders views/twiml/lead/answered.xml.erb' do
        post :answered, twilio_params
        expect(response).to render_template 'twiml/lead/answered'
      end

      context 'when call is answered by human and CallStatus == "in-progress"' do
        context 'when caller is still connected' do
          before do
            campaign.account.update_attributes(record_calls: true)
            post :answered, twilio_params
          end

          it 'updates RedisStatus for caller session to On call' do
            status, time = RedisStatus.state_time(campaign.id, caller_session.id)
            expect(status).to eq 'On call'
          end
          it 'queues VoterConnectedPusherJob' do
            expect([:sidekiq, :call_flow]).to have_queued(VoterConnectedPusherJob).with(caller_session.id, twilio_params['CallSid'])
          end
          it 'sets @record_calls = campaign.account.record_calls' do
            expect(assigns[:dialed_call].record_calls).to eq 'true'
          end
          it 'sets @twiml_flag = :connect' do
            expect(assigns[:dialed_call].twiml_flag).to eq :connect
          end
        end
        context 'caller has disconnected' do
          before do
            caller_session.update_attributes!({on_call: false, available_for_call: false})
          end
          it 'sets @twiml_flag = :hangup' do
            post :answered, twilio_params
            expect(assigns[:dialed_call].twiml_flag).to eq :hangup
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
              post :answered, machine_twilio_params
            end
            it 'sets @twiml_flag = :leave_message' do
              post :answered, machine_twilio_params
              expect(assigns[:dialed_call].twiml_flag).to eq :leave_message
            end
          end
          context 'and this is not first dial for phone' do
            before do
              allow(answering_machine_agent).to receive(:leave_message?){ false }
            end
            it 'sets @twiml_flag = :hangup' do
              post :answered, machine_twilio_params
              expect(assigns[:dialed_call].twiml_flag).to eq :hangup
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

      it_behaves_like 'answered call of any dialing mode'
      it_behaves_like 'Preview or Power dial modes'
    end

    context 'Power dial mode' do
      let(:campaign){ create(:power) }
      
      it_behaves_like 'answered call of any dialing mode'
      it_behaves_like 'Preview or Power dial modes'
    end

    context 'Predictive dial mode' do
      let(:campaign){ create(:predictive) }

      before do
        RedisOnHoldCaller.add(campaign.id, caller_session.id)
      end

      it_behaves_like 'answered call of any dialing mode'
    end
  end
end

