##
# @account is inherited from +ClientController#check_login+.
#
class Client::Billing::SubscriptionController < ClientController

  rescue_from Stripe::InvalidRequestError, with: :stripe_invalid_request_error
  rescue_from Stripe::APIConnectionError, with: :stripe_api_connection_error
  rescue_from ::Billing::Plans::InvalidPlanTransition, with: :flash_render_edit

private
  def flash_i18n_now(flash_key, i18n_key)
    flash.now[flash_key] = [I18n.t(i18n_key)]
  end
  def log_exception(exception)
    Rails.logger.error("RescuedException: #{exception.class} -- #{exception.message}")
  end
  def stripe_invalid_request_error(exception)
    log_exception(exception)
    flash_i18n_now(:error, 'stripe.invalid_request_error')
    render :edit
  end
  def stripe_api_connection_error(exception)
    log_exception(exception)
    flash_i18n_now(:error, 'stripe.api_error')
    render :edit
  end

  def flash_render_edit(exception)
    flash.now[:error] = [exception.message]
    render :edit
  end

  def subscription
    @subscription ||= @account.billing_subscription
  end

  def quota
    @quota ||= @account.quota
  end

  def credit_card
    @credit_card ||= @account.billing_credit_card
  end

  def plan
    params[:plan] || subscription.plan
  end

  def callers_allowed
    params[:caller_seats] || quota.callers_allowed
  end

  def amount_paid
    params[:amount_paid]
  end

  def autorecharge_settings
    params[:autorecharge] || {}
  end

  def any_plan_changes?
    plan != subscription.plan ||
    callers_allowed.try(:to_i) != quota.callers_allowed ||
    amount_paid.present?
  end

  def update_plan!
    customer_id = account.billing_provider_customer_id
    manager     = ::Billing::SubscriptionManager.new(customer_id, subscription, quota)
    manager.update!(plan, {
      callers_allowed: callers_allowed,
      amount_paid: amount_paid
    }) do |provider_object, opts|
      subscription.plan_changed!(plan, provider_object, opts)
      quota.plan_changed!(plan, provider_object, opts)
    end
  end

public
  def show
    subscription
    quota
    credit_card
  end

  def update
    if any_plan_changes?
      update_plan!
      flash_message(:notice, I18n.t('subscriptions.upgrade.success'))
    elsif not autorecharge_settings.empty?
      subscription.update_autorecharge_settings!(autorecharge_settings)
      flash_message(:notice, I18n.t('subscriptions.autorecharge.update'))
    else
      flash_message(:notice, I18n.t('subscriptions.nothing_to_do'))
    end
    redirect_to client_billing_subscription_path
  end

  def edit
    subscription
    quota
  end
end
