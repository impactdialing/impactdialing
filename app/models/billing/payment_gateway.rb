class Billing::PaymentGateway
  attr_reader :customer_id, :event_id

  def initialize(customer_id=nil, event_id=nil)
    @customer_id = customer_id
    @event_id    = event_id
  end

  def event
    return nil if event_id.nil?
    @event ||= Stripe::Event.retrieve(event_id)
  end

  def customer
    return nil if customer_id.nil?
    @customer ||= Stripe::Customer.retrieve(customer_id)
  end

  def card
    return nil if customer_id.nil?
    @card ||= customer.cards.retrieve(customer.default_card)
  end

  def subscription
    return nil if customer_id.nil?
    @subscription ||= customer.subscriptions.data.first
  end

  def create_customer_with_card(email, token)
    Stripe::Customer.create(card: token, email: email)
  end

  def update_customer_and_card(email, token)
    customer.email = email unless email.blank?
    customer.card  = token
    customer.save
    return customer
  end

  def update_subscription(plan_id, quantity, prorate=false)
    customer.update_subscription({
      plan: stripe_plan_id(plan_id),
      quantity: quantity,
      prorate: prorate
    })
  end

  def create_charge(usd_paid)
    Stripe::Charge.create({
      amount: usd_paid.to_i*100,
      currency: "usd",
      customer: customer.id
    })
  end

  def create_and_pay_invoice
    invoice = Stripe::Invoice.create(customer: customer_id)
    invoice.pay
  end

  def stripe_plan_id(plan)
    "ImpactDialing-#{plan.camelize}"
  end

  def cancel_subscription
    if subscription.present?
      customer.cancel_subscription
    end
  end

  def create_customer_charge(token, email, amount)
    Stripe::Charge.create(amount: amount, currency: "usd", customer: customer_id)
  end
end
