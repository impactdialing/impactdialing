class AccountUsageRender < AbstractController::Base
  include AbstractController::Rendering
  include AbstractController::Layouts
  include AbstractController::Helpers
  include AbstractController::Translation
  include AbstractController::AssetPaths

  self.view_paths = "app/views"
  layout "email"

  def by_campaigns(content_type, billable_totals, grand_total, campaigns)
    @billable_totals = billable_totals
    @grand_total     = grand_total
    @campaigns       = campaigns
    opts             = {
      template: "account_usage_mailer/by_campaigns.#{content_type}",
      format: content_type
    }
    render(opts)
  end

  def by_callers(content_type, billable_totals, status_totals, grand_total, callers)
    @billable_totals = billable_totals
    @status_totals   = status_totals
    @grand_total     = grand_total
    @callers         = callers
    opts             = {
      template: "account_usage_mailer/by_callers.#{content_type}",
      format: content_type
    }
    render(opts)
  end

  def by_account(content_type, from_date, to_date, billable_totals, undebited_totals, grand_total, accounts)
    @from_date        = from_date
    @to_date          = to_date
    @billable_totals  = billable_totals
    @undebited_totals = undebited_totals
    @grand_total      = grand_total
    @accounts         = accounts
    opts              = {
      template: "account_usage_mailer/by_account.#{content_type}",
      formate:  content_type
    }
    render(opts)
  end
end
