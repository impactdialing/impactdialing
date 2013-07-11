require "spec_helper"

describe Client::ReportsController do
  let(:account) { Factory(:account)}
  let(:user) { Factory(:user, :account => account) }

  before(:each) do
    login_as user
  end

  describe "caller reports" do

    it "lists all callers" do
      3.times{Factory(:caller, :account => account, active: true)}
      get :index
      assigns(:callers).should == account.callers.active
    end

  end

  describe 'usage report' do
    let!(:from_time) { 5.minutes.ago.to_s }
    let!(:time_now) { Time.now.to_s }

    describe 'call attempts' do
      before(:each) do
        campaign = Factory(:predictive, :account => user.account)
        Factory(:caller_session, campaign: campaign)
        Factory(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (10.minutes + 2.seconds), :tDuration => 10.minutes + 2.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::VOICEMAIL, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (1.minutes + 3.seconds), :tDuration => 1.minutes + 3.seconds, :status => CallAttempt::Status::VOICEMAIL, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (101.minutes + 57.seconds), :tDuration => 101.minutes + 57.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::ABANDONED, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (10.seconds), :tDuration => 10.seconds, :status => CallAttempt::Status::ABANDONED, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:transfer_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (10.minutes + 2.seconds), tDuration: 10.minutes + 2.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:transfer_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (1.minutes + 20.seconds), tDuration: 1.minutes+ 20.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        get :usage, :campaign_id => campaign.id
      end

      it "billable minutes" do
        CallAttempt.lead_time(nil, @campaign, from_time, time_now).should == 113
      end

      it "billable voicemails" do
        assigns(:campaign).voicemail_time(from_time, time_now).should == 3
      end

      it "billable abandoned calls" do
        assigns(:campaign).abandoned_calls_time(from_time, time_now).should == 2
      end

      it "billable transfer calls" do
        assigns(:campaign).transfer_time(from_time, time_now).should == 13
      end

    end

    describe 'utilization' do

      before(:each) do
        @campaign = Factory(:preview, :account => user.account)
        Factory(:caller_session, caller_type: "Phone", tStartTime: Time.now, tEndTime: Time.now + (30.minutes + 2.seconds), :tDuration => 30.minutes + 2.seconds, :campaign => @campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }
        Factory(:caller_session, tStartTime: Time.now, tEndTime: Time.now + (101.minutes + 57.seconds), :tDuration => 101.minutes + 57.seconds, :campaign => @campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }
        Factory(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (10.minutes + 10.seconds), wrapup_time: Time.now + (10.minutes + 40.seconds), :tDuration => 10.minutes + 10.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => @campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }
        Factory(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::VOICEMAIL, :campaign => @campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }
        Factory(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (101.minutes + 57.seconds), wrapup_time: Time.now + (102.minutes + 57.seconds), :tDuration => 101.minutes + 57.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => @campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }
        Factory(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::ABANDONED, :campaign => @campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }
        get :usage, :campaign_id => @campaign.id
      end

      it "logged in caller session" do
        CallerSession.time_logged_in(nil, @campaign, from_time, time_now).should == 7919
      end

      it "on call time" do
        CallAttempt.time_on_call(nil, @campaign, from_time, time_now).should == 6727
      end

      it "on wrapup time" do
        CallAttempt.time_in_wrapup(nil, @campaign, from_time, time_now).should == 90
      end

      it "minutes" do
        CallerSession.caller_time(nil, @campaign, from_time, time_now).should == 31
      end

    end
  end


  describe "download report" do

    it "pulls up report downloads page" do
      campaign = Factory(:preview, script: Factory(:script), account: account)
      Resque.should_receive(:enqueue)
      get :download, :campaign_id => campaign.id, format: 'html'
      response.should redirect_to 'http://test.host/client/reports'
    end

    it "sets the default date range according to the campaign's time zone" do
      time_zone = ActiveSupport::TimeZone.new("Pacific Time (US & Canada)")
      campaign = Factory(:preview, script: Factory(:script), :time_zone => time_zone.name, account: account)
      Time.stub(:now => Time.utc(2012, 2, 13, 0, 0, 0))
      get :download_report, :campaign_id => campaign.id
      response.should be_ok
      assigns(:from_date).to_s.should == "2012-02-12 08:00:00 UTC"
      assigns(:to_date).to_s.should == "2012-02-13 07:59:59 UTC"
    end

  end

end
