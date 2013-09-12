module Client::SubscriptionHelper
  def subscription_type_options_for_select
    return Subscription::Type::PAID_SUBSCRIPTIONS.map do |type|
      [subscription_human_type(type), type]
    end
  end

  def subscription_upgrade_button(subscription)
    button = []
    if subscription.stripe_customer_id.present?
      button << 'Upgrade'
      button << client_subscription_path(subscription)
      button << button_html_opts
    end
    return button
  end

  def subscription_update_billing_button(subscription)
    return [
      'Update billing info',
      update_billing_client_subscription_path(subscription),
      button_html_opts
    ]
  end

  def subscription_cancel_button(subscription)
    button = []
    if not subscription.trial?
      button << 'Cancel subscription'
      button << {
        action: 'cancel',
        id: subscription.id
      }
      button << {
        method: 'put',
        class: 'action secondary',
        confirm: 'Are you sure you want to cancel your subscription?'
      }
    end
    return button
  end

  def subscription_add_to_balance_button(subscription)
    return [
      'Add to your balance',
      add_funds_client_subscription_path(subscription),
      {class: 'action primary'}
    ]
  end

  def subscription_configure_auto_recharge_button(subscription)
    return [
      'Configure auto-recharge',
      configure_auto_recharge_client_subscription_path(subscription),
      {class: 'action primary'}
    ]
  end

  def subscription_human_type(type_or_subscription)
    type = if type_or_subscription.kind_of? ActiveRecord::Base
             type_or_subscription.type
           else
             type_or_subscription
           end
    return type.underscore.humanize
  end

  def subscription_buttons(subscription)
    buttons = []
    if subscription.per_agent?
      buttons << subscription_update_billing_button(subscription)
      upgrade_button = subscription_upgrade_button(subscription)
      buttons << upgrade_button if not upgrade_button.empty?
      cancel_button = subscription_cancel_button(subscription)
      buttons << cancel_button if not cancel_button.empty?
    elsif subscription.per_minute?
      buttons << subscription_add_to_balance_button(subscription)
      buttons << subscription_configure_auto_recharge_button(subscription)
      buttons << subscription_update_billing_button(subscription)
    end
    return buttons
  end

private

  def button_html_opts
    return @button_html_opts ||= {class: 'action primary confirm'}
  end
end