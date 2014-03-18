class BillingRender < AbstractController::Base
  include AbstractController::Rendering
  include AbstractController::Layouts
  include AbstractController::Helpers
  include AbstractController::Translation
  include AbstractController::AssetPaths

  self.view_paths = "app/views"
  layout "email"

private

public

  def autorecharge_failed(content_type, account)
    quota              = account.quota
    subscription       = account.subscription
    @minutes_attempted = subscription.autorecharge_minutes
    @amount            = subscription.autorecharge_amount
    @trigger           = subscription.autorecharge_trigger
    @minutes_available = quota.minutes_available
    opts               = {
      template: "billing_mailer/autorecharge_failed.#{content_type}",
      format: content_type
    }
    render(opts)
  end

  def autorenewal_failed(content_type, account)
    opts             = {
      template: "billing_mailer/autorenewal_failed.#{content_type}",
      format: content_type
    }
    render(opts)
  end
end
