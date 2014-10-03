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
    from_pool   = [params[:from_date], @account.created_at]
    to_pool     = [params[:to_date]]
    @date_range = Report::SelectiveDateRange.new from_pool, to_pool
  end

  def create
    from_pool  = [params[:from_date], @account.created_at]
    to_pool    = [params[:to_date]]
    date_range = Report::SelectiveDateRange.new from_pool, to_pool

    Resque.enqueue(ReportAccountUsageJob, params[:report_type], @user.id, date_range.from, date_range.to, session[:internal_admin])
    redirect_to client_account_usage_path(from_date: params[:from_date], to_date: params[:to_date]), notice: [t('account_usages.create.success')]
  end
end