require "spec_helper"

describe Client::ReportsController, :type => :controller do
  let!(:account) { create(:account)}
  let!(:user) { create(:user, :account => account) }
  let(:time_zone){ ActiveSupport::TimeZone.new("Pacific Time (US & Canada)") }

  before(:each) do
    login_as user
  end

  context 'campaign(s) and caller(s) exist' do
    let!(:campaign){ create(:preview, script: create(:script), :time_zone => time_zone.name, account: account) }
    let!(:caller){ create(:caller, campaign: campaign, account: account) }

    describe "caller reports" do
      it "lists all callers" do
        3.times{create(:caller, account: account, campaign: campaign, active: true)}
        get :index
        expect(assigns(:callers)).to eq(account.callers.active)
      end
    end

    describe 'usage report' do
      let!(:from_time) { 5.minutes.ago.to_s }
      let!(:time_now) { Time.zone.now.to_s }

      describe 'call attempts' do
        before(:each) do
          create(:caller, account: user.account, campaign: campaign, active: true)
          create(:caller_session, campaign: campaign)
          create(:call_attempt, connecttime: Time.zone.now, tStartTime: Time.zone.now, tEndTime: Time.zone.now + (10.minutes + 2.seconds), :tDuration => 10.minutes + 2.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
          create(:call_attempt, connecttime: Time.zone.now, tStartTime: Time.zone.now, tEndTime: Time.zone.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::VOICEMAIL, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
          create(:call_attempt, connecttime: Time.zone.now, tStartTime: Time.zone.now, tEndTime: Time.zone.now + (1.minutes + 3.seconds), :tDuration => 1.minutes + 3.seconds, :status => CallAttempt::Status::VOICEMAIL, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
          create(:call_attempt, connecttime: Time.zone.now, tStartTime: Time.zone.now, tEndTime: Time.zone.now + (101.minutes + 57.seconds), :tDuration => 101.minutes + 57.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
          create(:call_attempt, connecttime: Time.zone.now, tStartTime: Time.zone.now, tEndTime: Time.zone.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::ABANDONED, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
          create(:call_attempt, connecttime: Time.zone.now, tStartTime: Time.zone.now, tEndTime: Time.zone.now + (10.seconds), :tDuration => 10.seconds, :status => CallAttempt::Status::ABANDONED, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
          create(:transfer_attempt, connecttime: Time.zone.now, tStartTime: Time.zone.now, tEndTime: Time.zone.now + (10.minutes + 2.seconds), tDuration: 10.minutes + 2.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
          create(:transfer_attempt, connecttime: Time.zone.now, tStartTime: Time.zone.now, tEndTime: Time.zone.now + (1.minutes + 20.seconds), tDuration: 1.minutes+ 20.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
          get :usage, :campaign_id => campaign.id
        end

        it "billable minutes" do
          expect(CallAttempt.lead_time(nil, campaign, from_time, time_now)).to eq(113)
        end

        it "billable voicemails" do
          expect(assigns(:campaign).voicemail_time(from_time, time_now)).to eq(3)
        end

        it "billable abandoned calls" do
          expect(assigns(:campaign).abandoned_calls_time(from_time, time_now)).to eq(2)
        end

        it "billable transfer calls" do
          expect(assigns(:campaign).transfer_time(from_time, time_now)).to eq(13)
        end

      end

      describe 'utilization' do

        before(:each) do
          create(:caller_session, caller_type: "Phone", tStartTime: Time.zone.now, tEndTime: Time.zone.now + (30.minutes + 2.seconds), :tDuration => 30.minutes + 2.seconds, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }
          create(:caller_session, tStartTime: Time.zone.now, tEndTime: Time.zone.now + (101.minutes + 57.seconds), :tDuration => 101.minutes + 57.seconds, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }
          create(:call_attempt, connecttime: Time.zone.now, tStartTime: Time.zone.now, tEndTime: Time.zone.now + (10.minutes + 10.seconds), wrapup_time: Time.zone.now + (10.minutes + 40.seconds), :tDuration => 10.minutes + 10.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }
          create(:call_attempt, connecttime: Time.zone.now, tStartTime: Time.zone.now, tEndTime: Time.zone.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::VOICEMAIL, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }
          create(:call_attempt, connecttime: Time.zone.now, tStartTime: Time.zone.now, tEndTime: Time.zone.now + (101.minutes + 57.seconds), wrapup_time: Time.zone.now + (102.minutes + 57.seconds), :tDuration => 101.minutes + 57.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }
          create(:call_attempt, connecttime: Time.zone.now, tStartTime: Time.zone.now, tEndTime: Time.zone.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::ABANDONED, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }
          get :usage, :campaign_id => campaign.id
        end

        it "logged in caller session" do
          expect(CallerSession.time_logged_in(nil, campaign, from_time, time_now)).to eq(7919)
        end

        it "on call time" do
          expect(CallAttempt.time_on_call(nil, campaign, from_time, time_now)).to eq(6727)
        end

        it "on wrapup time" do
          expect(CallAttempt.time_in_wrapup(nil, campaign, from_time, time_now)).to eq(90)
        end

        it "minutes" do
          expect(CallerSession.caller_time(nil, campaign, from_time, time_now)).to eq(31)
        end

      end
    end


    describe "download report" do
      it "pulls up report downloads page" do
        expect(Resque).to receive(:enqueue)
        get :download, :campaign_id => campaign.id, format: 'html'
        expect(response).to redirect_to 'http://test.host/client/reports'
      end

      it "sets the default date range according to the campaign's time zone" do
        Timecop.freeze do
          expected_from = Time.now.in_time_zone(campaign.time_zone).beginning_of_day.utc
          expected_to = Time.now.in_time_zone(campaign.time_zone).end_of_day.utc

          get :download_report, :campaign_id => campaign.id

          expect(response).to be_ok
          expect(assigns(:date_range).from.to_s).to eq(expected_from.to_s)
          expect(assigns(:date_range).to.to_s).to eq(expected_to.to_s)
        end
      end

    end
  end

  context 'campaign(s) or caller(s) do not exist' do
    it 'redirects to root_path' do
      get :index
      expect(response).to redirect_to client_root_path
    end
    it 'with a notice' do
      get :index
      expect(flash[:notice]).not_to be_empty
    end
  end
end
