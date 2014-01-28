class Client::AccountUsagesController < ClientController
  include TimeZoneHelper

  before_filter :validate_create_params, only: [:create]

private
  def required_create_params
    [:report_type, :from_date, :to_date]
  end

  def validate_create_params
    available = required_create_params.map{|r| [r, params[r]]}
    fail = available.detect{|a| a.last.blank?}
    if !!fail
      redirect_to client_account_usage_path, flash: {error: [t("account_usages.create.#{fail.first}_required")]}
    end
  end

public
  def show
    @from_date, @to_date = set_date_range_account(@account, nil, nil)
  end

  def create
    from_date, to_date = set_date_range_account(@account, params[:from_date], params[:to_date])
    Resque.enqueue(ReportAccountUsageJob, params[:report_type], @user.id, from_date, to_date)
    redirect_to client_account_usage_path, notice: [t('account_usages.create.success')]
  end
end