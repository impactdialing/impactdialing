class Debit
  attr_reader :call_time, :quota, :account, :available_minutes, :trigger, :payment_pending, :autorecharge_active

  def initialize(call_time, quota, account)
    @call_time           = call_time
    @quota               = quota
    @account             = account
    @available_minutes   = quota.minutes_available
    @subscription        = account.billing_subscription
    @autorecharge_active = @subscription.autorecharge_active?
    @trigger             = @subscription.autorecharge_trigger
    @payment_pending     = @subscription.autorecharge_pending?
  end

  def process
    call_time.debited = quota.debit(minutes)
    if recharge_needed?
      Resque.enqueue(Billing::Jobs::AutoRecharge, account.id)
    end
    return call_time
  end

private
  def minutes
    (call_time.tDuration.to_f/60).ceil
  end

  def recharge_needed?
    autorecharge_active && (available_minutes < trigger) && (not payment_pending)
  end
end
