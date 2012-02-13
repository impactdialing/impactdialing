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
        Factory(:call_attempt, :tDuration => 10.minutes + 2.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:call_attempt, :tDuration => 1.minutes, :status => CallAttempt::Status::VOICEMAIL, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:call_attempt, :tDuration => 101.minutes + 57.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:call_attempt, :tDuration => 1.minutes, :status => CallAttempt::Status::ABANDONED, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
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
        Factory(:caller_session, :tDuration => 10.minutes + 2.seconds, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:caller_session, :tDuration => 101.minutes + 57.seconds, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
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
      campaign = Factory(:campaign, script: Factory(:script), :time_zone => "Pacific Time (US & Canada)")
      Time.stub(:now => Time.utc(2012, 2, 13, 0, 0, 0))
      get :download_report, :campaign_id => campaign.id
      response.should be_ok
      assigns(:from_date).should == Date.new(2012, 2, 12)
      assigns(:to_date).should == Date.new(2012, 2, 12)
    end

  end

end
