require "spec_helper"

describe Client::ReportsController do
  let(:user) { Factory(:user) }

  before(:each) do
    login_as user
  end

  describe 'usage report' do
    describe 'call attempts' do
      before(:each) do
        campaign = Factory(:campaign, :account => user.account)
        time_now = Time.now
        Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (10.minutes + 2.seconds), :tDuration => 10.minutes + 2.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (1.minutes),:tDuration => 1.minutes, :status => CallAttempt::Status::VOICEMAIL, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (101.minutes + 57.seconds),:tDuration => 101.minutes + 57.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (1.minutes),:tDuration => 1.minutes, :status => CallAttempt::Status::ABANDONED, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        get :usage, :id => campaign.id
      end

      it "seconds" do
        assigns(:utilised_call_attempts_seconds).should == "113.59"
      end

      it "minutes" do
        assigns(:utilised_call_attempts_minutes).should == 115
      end

      it "billable seconds" do
        assigns(:billable_call_attempts_seconds).should == "111.59"
      end

      it "billable minutes" do
        assigns(:billable_call_attempts_minutes).should == 113
      end
    end

    describe 'caller sessions' do
      before(:each) do
        campaign = Factory(:campaign, :account => user.account)
        time_now = Time.now
        Factory(:caller_session,starttime: Time.now, endtime: Time.now + (10.minutes + 2.seconds),  :tDuration => 10.minutes + 2.seconds, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:caller_session,starttime: Time.now, endtime: Time.now + (101.minutes + 57.seconds), :tDuration => 101.minutes + 57.seconds, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        get :usage, :id => campaign.id
      end

      it "seconds" do
        assigns(:caller_sessions_seconds).should == "111.59"
      end

      it "minutes" do
        assigns(:caller_sessions_minutes).should == 113
      end
    end
  end
  
  

  describe "download report" do

    it "pulls up report downloads page" do
      campaign = Factory(:campaign, script: Factory(:script))
      Delayed::Job.should_receive(:enqueue)
      get :download, :campaign_id => campaign.id, format: 'csv'
      response.should redirect_to 'https://test.host/client/reports'
    end

    it "sets the default date range according to the campaign's time zone" do
      time_zone = ActiveSupport::TimeZone.new("Pacific Time (US & Canada)")
      campaign = Factory(:campaign, script: Factory(:script), :time_zone => time_zone.name)
      Time.stub(:now => Time.utc(2012, 2, 13, 0, 0, 0))
      get :download_report, :campaign_id => campaign.id
      response.should be_ok
      assigns(:from_date).to_i.should == time_zone.local(2012, 2, 12, 0).to_i
      assigns(:to_date).to_i.should == time_zone.local(2012, 2, 12, 23, 59, 59).to_i
    end

  end

end
