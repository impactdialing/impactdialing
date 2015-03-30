require 'rails_helper'
require 'app_health/monitor/dial_rate'

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
    RedisPredictiveCampaign.add(predictiveA.id, predictiveA.type)
    RedisPredictiveCampaign.add(predictiveB.id, predictiveB.type)
  end

  after do
    RedisPredictiveCampaign.remove(predictiveA.id, predictiveA.type)
    RedisPredictiveCampaign.remove(predictiveB.id, predictiveB.type)
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
              create(:call_attempt, campaign: predictiveA, created_at: 3.minutes.ago)
            end
            it 'returns false' do
              expect(subject.ok?).to be_falsey
            end
          end
          context '1 new dial was made in last minute' do
            before do
              create(:call_attempt, campaign: predictiveA)
            end
            it 'returns true' do
              expect(subject.ok?).to be_truthy
            end
          end
        end
      end
    end
  end
end
