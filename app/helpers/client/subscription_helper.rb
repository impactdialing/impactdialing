module Client::SubscriptionHelper
  def subscription_type_options_for_select
    Subscription::Type::PAID_SUBSCRIPTIONS.map do |type|
      [type.underscore.humanize, type]
    end
  end

  def subscription_upgrade_button(subscription)
    if subscription.stripe_customer_id.present?
      html_opts = {class: 'action primary confirm'}
      return link_to 'Upgrade', client_subscription_path(subscription), html_opts
    else
      html_opts = {
        class: 'disabled',
        title: 'Please provide billing info before upgrading.'
      }
      return content_tag :span, 'Upgrade', html_opts
    end
  end
end