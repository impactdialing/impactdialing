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
    customer.cards.retrieve(customer.default_card)
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

  def create_customer_charge(token, email, amount)
    Stripe::Charge.create(amount: amount, currency: "usd", customer: customer_id)
  end

  def update_subscription_plan(params)
    customer.update_subscription(params)
  end

  def recharge
    Stripe::Charge.create(amount: amount_paid.to_i*100, currency: "usd", customer: customer_id)
  end

  def invoice_customer
    begin
      invoice = Stripe::Invoice.create(customer: customer_id)
      invoice.pay
    rescue
    end
  end

  def cancel_subscription
    if per_agent?
      stripe_customer = Stripe::Customer.retrieve(customer_id)
      stripe_customer.cancel_subscription
    end
  end
end
