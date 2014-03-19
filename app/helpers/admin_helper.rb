module AdminHelper
  def admin_switch_account_to_manual_link(account)
    plan_id = account.billing_subscription.plan
    if Billing::Plans.is_enterprise?(plan_id)
      text = 'set account to trial'
    else
      text = 'set account to enterprise'
    end
    link_to(text, "/admin/toggle_enterprise_trial/#{account.id}", method: :put)
  end

  def admin_toggle_dialer_access_link(account)
    quota = account.quota
    if quota.disable_calling?
      text = 'Allow Dialer Access'
    else
      text = 'Deny Dialer Access'
    end
    link_to text, "/admin/toggle_calling/#{account.id}", method: :put
  end
end