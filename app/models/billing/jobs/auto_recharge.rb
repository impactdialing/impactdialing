class Billing::Jobs::AutoRecharge
  @queue = :background_worker

  def self.perform(account_id)
    account      = Account.find account_id
    subscription = account.billing_subscription
    customer_id  = account.billing_provider_customer_id
    plan_id      = subscription.plan
    plan         = plans.find(plan_id)

    # only recharge per_minute
    return unless plan.per_minute?

    trigger           = subscription.autorecharge_trigger
    amount            = subscription.autorecharge_amount
    payment_pending   = subscription.autorecharge_pending?
    quota             = account.quota
    minutes_available = quota.minutes_available
    recharge_needed   = minutes_available < trigger && (not payment_pending)

    return unless recharge_needed

    manager     = ::Billing::SubscriptionManager.new(customer_id, subscription, quota)
    manager.update!(plan_id, {
      amount_paid: amount,
      autorecharge: 1
    }) do |provider_object, opts|
      subscription.autorecharge_pending!
      quota.plan_changed!(plan_id, provider_object, opts)
    end
  end

  def self.plans
    @plans ||= Billing::Plans.new
  end
end