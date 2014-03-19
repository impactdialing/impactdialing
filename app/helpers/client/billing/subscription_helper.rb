module Client::Billing::SubscriptionHelper
  def subscription_type_options_for_select(subscription, minutes_available)
    ids = ::Billing::Plans.permitted_ids_for(subscription.plan, minutes_available)
    return ids.map do |type|
      [subscription_human_type(type), type]
    end
  end

  def subscription_human_type(plan_id)
    return plan_id.humanize
  end

  def subscription_upgrade_button(subscription)
    button = []
    if can?(:make_payment, subscription) && can?(:change_plans, subscription)
      button << 'Upgrade'
      button << edit_client_billing_subscription_path
      button << button_html_opts
    end
    return button
  end

  def subscription_update_billing_button(subscription)
    return [
      'Update card',
      client_billing_credit_card_path,
      button_html_opts
    ]
  end

  def subscription_cancel_button(subscription)
    button = []
    if can? :cancel_subscription, subscription
      button << 'Cancel subscription'
      button << {
        action: 'cancel'
      }
      button << {
        method: 'put',
        class: 'action secondary',
        confirm: 'Are you sure you want to cancel your subscription?'
      }
    end
    return button
  end

  def subscription_buttons(subscription)
    buttons        = []
    upgrade_button = subscription_upgrade_button(subscription)
    cancel_button  = subscription_cancel_button(subscription)

    buttons << upgrade_button if not upgrade_button.empty?
    buttons << subscription_update_billing_button(subscription)
    buttons << cancel_button if not cancel_button.empty?

    return buttons
  end

private

  def button_html_opts
    return @button_html_opts ||= {class: 'action primary confirm'}
  end
end
