class AccountUsageRender < AbstractController::Base
  include AbstractController::Rendering
  include AbstractController::Layouts
  include AbstractController::Helpers
  include AbstractController::Translation
  include AbstractController::AssetPaths

  self.view_paths = "app/views"
  layout "email"

  # helper ApplicationHelper

  # You can define custom helper methods to be used in views here
  # helper_method :current_admin
  # def current_admin; nil; end

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
end
