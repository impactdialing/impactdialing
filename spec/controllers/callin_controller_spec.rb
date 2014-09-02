require "spec_helper"

describe CallinController, :type => :controller do
  describe 'Caller Calling In' do
    let(:account) { create(:account, :activated => true) }
    let(:campaign) { create(:predictive, :account => account, :start_time => Time.new("2000-01-01 01:00:00"), :end_time => Time.new("2000-01-01 23:00:00"))}

    it "prompts for PIN for a caller " do
      post :create
      resp = Twilio::Verb.new do |v|
        3.times do
          v.gather(:finishOnKey => '*', :timeout => 10, :action => identify_caller_url(:host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, :protocol => "http://",  :attempt => 1), :method => "POST") do
            v.say "Please enter your pin and then press star."
          end
        end
      end.response
      expect(response.body).to eq(resp)
    end

    it "verifies the logged in caller by session pin" do
      pin = rand.to_s[2..6]
      campaign = create(:campaign)
      caller = create(:caller, :account => account, :campaign => campaign)
      caller_identity = create(:caller_identity, :caller => caller, :session_key => 'key' , pin: pin)
      caller_session = create(:webui_caller_session, caller: caller, campaign: campaign)
      expect(CallerIdentity).to receive(:find_by_pin).and_return(caller_identity)
      expect(caller_identity).to receive(:caller).and_return(caller)
      expect(caller).to receive(:create_caller_session).and_return(caller_session)
      expect(CallerSession).to receive(:find_by_id_cached).with(caller_session.id).and_return(caller_session)
      expect(RedisPredictiveCampaign).to receive(:add).with(caller.campaign_id, caller.campaign.type)
      expect(caller_session).to receive(:start_conf).and_return("")
      post :identify, Digits: pin
    end

    it "Prompts on incorrect pin" do
      pin = rand.to_s[2..6]
      allow(CallerIdentity).to receive(:find_by_pin).and_return(nil)
      post :identify, :Digits => pin, :attempt => "1"
      expect(response.body).to eq(Twilio::Verb.new do |v|
        3.times do
          v.gather(:finishOnKey => '*', :timeout => 10, :action => identify_caller_url(:host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, :protocol => "http://", :attempt => 2), :method => "POST") do
            v.say "Incorrect Pin. Please enter your pin and then press star."
          end
        end
      end.response)
    end

    it "Hangs up on incorrect pin after the third attempt" do
      pin = rand.to_s[2..6]
      allow(CallerIdentity).to receive(:find_by_pin).and_return(nil)
      post :identify, :Digits => pin, :attempt => 3
      expect(response.body).to eq(Twilio::Verb.new do |v|
        v.say "Incorrect Pin."
        v.hangup
      end.response)
    end

    it 'seeds redis script questions cache when caller is phones only' do
      caller = create(:caller, account: account, campaign: campaign, is_phones_only: true)
      caller_session = create(:phones_only_caller_session, {caller: caller, campaign: campaign})

      expect(Resque).to receive(:enqueue).with(CachePhonesOnlyScriptQuestions, anything, 'seed')
      post :identify, :Digits => caller.pin
    end

    it 'renders abort twiml unless the campaign is fit to start calling' do
      account.quota.update_attributes!(minutes_allowed: 0)
      caller         = create(:caller, account: account, campaign: campaign)
      caller_session = create(:webui_caller_session, {caller: caller, campaign: campaign})
      expected_twiml = caller_session.account_has_no_funds_twiml

      post :identify, :Digits => caller.pin
      expect(response.body).to eq expected_twiml
    end
  end
end
