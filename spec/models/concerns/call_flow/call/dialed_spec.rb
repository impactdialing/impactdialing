require 'rails_helper'

describe 'CallFlow::Call::Dialed' do
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

  describe '.create(campaign, rest_response)' do
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

