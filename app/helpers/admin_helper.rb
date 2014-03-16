module AdminHelper
  def admin_switch_account_to_manual_link(account)
    plan_id = account.billing_subscription.plan
    if Billing::Plans.is_enterprise?(plan_id)
      "Enterprise (manual)"
    else
      link_to("set account to manual", "/admin/set_account_to_manual/#{account.id}", method: :put)
    end
  end
end