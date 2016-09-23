module AdminHelper
  def admin_account_billing_subscription_link(account)
    subscription = account.billing_subscription
    plan = subscription.plan.humanize
    cost = "$#{subscription.price_per_quantity} /min"
    text = "#{subscription.plan.humanize} (#{cost})"
    link_to(text, admin_account_billing_subscriptions_path(account))
  end

  def admin_subscription_trigger_form_tag(subscription)
    form_tag(admin_account_billing_subscriptions_path(subscription.account), {
      method: :put
    })
  end

  def admin_make_trial_trigger(subscription)
    return '' if subscription.plan == 'trial'

    str = admin_subscription_trigger_form_tag(subscription)
    str << hidden_field_tag('billing_subscription[plan]', 'trial')
    str << submit_tag("Make Trial", {
             data: {
               confirm: "Cancel customer subscription (if any) and reset account quota to 50 minutes and 5 caller seats?"
             }
           })
    str << "</form>".html_safe
  end

  def admin_make_enterprise_trigger(subscription)
    return '' if subscription.plan == 'enterprise'

    str = admin_subscription_trigger_form_tag(subscription)
    str << hidden_field_tag('billing_subscription[plan]', 'enterprise')
    str << submit_tag("Make Enterprise", {
             data: {
               confirm: "Cancel customer subscription (if any) and lift all account quotas for manual billing?"
             }
           })
    str << "</form>".html_safe
  end

  def admin_toggle_dialer_access_link(account)
    quota = account.quota
    return 'All access denied' if quota.disable_access?

    if quota.disable_calling?
      text = 'Allow Dialer'
    else
      text = 'Deny Dialer'
    end
    link_to text, "/admin/toggle_calling/#{account.id}", method: :put
  end

  def admin_toggle_all_access_link(account)
    quota = account.quota
    if quota.disable_access?
      text = 'Allow All'
    else
      text = 'Deny All'
    end
    link_to text, "/admin/toggle_access/#{account.id}", method: :put
  end

  def admin_toggle_abandonment_link(account)
    text = 'Set to '
    text += account.variable_abandonment? ? 'Fixed' : 'Variable'
    link_to text, "/admin/abandonment/#{account.id}", method: :put
  end
end
