require "spec_helper"

describe Client::ReportsController do
  let(:user) { Factory(:user) }

  before(:each) do
    login_as user
  end

  describe 'usage report' do
    before(:each) do
      campaign = Factory(:campaign)
      time_now = Time.now
      Factory(:call_attempt, :call_start => time_now, :call_end => time_now + 10.minutes, :status => CallAttempt::Status::SUCCESS, :campaign => campaign)
      Factory(:call_attempt, :call_start => time_now, :call_end => time_now + 101.minutes, :status => CallAttempt::Status::SUCCESS, :campaign => campaign)
      Factory(:call_attempt, :call_start => time_now, :call_end => time_now + 20.minutes, :status => CallAttempt::Status::VOICEMAIL, :campaign => campaign)
      Factory(:call_attempt, :call_start => time_now, :call_end => time_now + 30.minutes, :status => CallAttempt::Status::VOICEMAIL, :campaign => campaign)
      get :usage, :id => campaign.id
    end

    it "reports call minutes" do
      assigns(:call_minutes).should == 111
    end

    it "reports voicemail minutes" do
      assigns(:voicemail_minutes).should == 50
    end


  end

end
