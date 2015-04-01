require 'rails_helper'
require 'app_health/monitor/predictive_dial_rate'
require 'app_health/alarm'

describe 'AppHealth::Monitor::PredictiveDialRate' do
  let(:power) do
    create(:power)
  end
  let(:predictiveA) do
    create(:predictive)
  end
  let(:predictiveB) do
    create(:predictive)
  end

  before do
    Redis.new.flushall
    RedisPredictiveCampaign.add(predictiveA.id, predictiveA.type)
    RedisPredictiveCampaign.add(predictiveB.id, predictiveB.type)
  end

  after do
    Redis.new.flushall
  end

  describe 'ok?' do
    subject{ AppHealth::Monitor::PredictiveDialRate }

    context 'no callers calling' do
      it 'returns true' do
        expect(subject.ok?).to be_truthy
      end
    end

    context 'some callers calling' do
      before do
        create_list(:webui_caller_session, 3, available_for_call: false, on_call: true, campaign: predictiveA)
        create_list(:webui_caller_session, 3, available_for_call: false, on_call: true, campaign: predictiveB)
      end

      context 'no on-hold calling callers' do
        it 'returns true' do
          expect(subject.ok?).to be_truthy
        end
      end

      context 'at least 1 caller is on-hold' do
        let(:on_hold_session){ predictiveA.caller_sessions.last }

        before do
          on_hold_session.update_attributes!({
            available_for_call: true
          })
        end

        context 'caller has been on-hold less than 1 minute' do
          before do
            RedisStatus.set_state_changed_time(predictiveA.id, 'On hold', on_hold_session.id)
          end
          it 'returns true' do
            expect(subject.ok?).to be_truthy
          end
        end
        context 'caller has been on-hold more than 1 minute' do
          before do
            Timecop.travel(2.minutes.ago) do
              RedisStatus.set_state_changed_time(predictiveA.id, 'On hold', on_hold_session.id)
            end
          end
          context 'no new dials have been made in last 2 minutes' do
            before do
              create(:bare_call_attempt, campaign: predictiveA, created_at: 3.minutes.ago, caller_session: predictiveA.caller_sessions.sample)
            end
            it 'returns false' do
              expect(subject.ok?).to be_falsey
            end
          end
          context '1 new dial was made in last minute' do
            it 'returns true' do
              call_attempt = create(:bare_call_attempt, campaign: predictiveA, caller_session: predictiveA.caller_sessions.sample)
              expect(subject.ok?).to be_truthy
            end
          end
        end
      end
    end
  end

  describe '.alert_if_not_ok' do
    subject{ AppHealth::Monitor::PredictiveDialRate }
    
    before do
      create_list(:webui_caller_session, 3, available_for_call: false, on_call: true, campaign: predictiveA)
      create_list(:webui_caller_session, 3, available_for_call: false, on_call: true, campaign: predictiveB)
    end

    context '.ok? => false' do
      let(:on_hold_session){ predictiveA.caller_sessions.last }

      before do
        on_hold_session.update_attributes!({
          available_for_call: true
        })

        Timecop.travel(2.minutes.ago) do
          RedisStatus.set_state_changed_time(predictiveA.id, 'On hold', on_hold_session.id)
        end

        create(:call_attempt, campaign: predictiveA, created_at: 3.minutes.ago, caller_session: predictiveA.caller_sessions.sample)
      end
      it 'triggers an Alarm' do
        expect(AppHealth::Alarm).to receive(:trigger!).with(subject.new.alarm_key, subject.new.alarm_description, subject.new.alarm_details)
        subject.alert_if_not_ok
      end
    end
    context '.ok? => true' do
      it 'does nothing' do
        expect(AppHealth::Alarm).not_to receive(:trigger!)
        subject.alert_if_not_ok
      end
    end
  end
end
