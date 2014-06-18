require 'spec_helper'

describe Client::AccountUsagesController do
  let(:account) do
    create(:account)
  end
  let(:user) do
    create(:user, {
      account: account
    })
  end
  let(:from_date){ '09/09/2013' }
  let(:to_date){ '01/24/2014' }
  let(:db_from_date) do
    Time.utc('2013','09','09').beginning_of_day
  end
  let(:db_to_date) do
    Time.utc('2014','01','24').end_of_day
  end
  let(:report_type){ 'campaigns' }
  let(:valid_params) do
    {
      report_type: report_type,
      from_date: from_date,
      to_date: to_date
    }
  end

  before do
    login_as(user)
  end

  describe 'show' do
    it 'sets @from_date' do
      get :show
      assigns[:from_date].should_not be_blank
    end

    it 'sets @to_date' do
      get :show
      assigns[:to_date].should_not be_blank
    end
  end

  describe 'create, :from_date, :to_date, :report_type' do
    before do
      Resque.stub(:enqueue)
    end
    it 'queues a new ReportAccountUsageJob' do
      Resque.should_receive(:enqueue).
        with(ReportAccountUsageJob, report_type, user.id, db_from_date, db_to_date, nil)
      post :create, valid_params
    end
    it 'redirects to client_account_usage_path' do
      post :create, valid_params
      response.should redirect_to client_account_usage_path
    end
  end
end
