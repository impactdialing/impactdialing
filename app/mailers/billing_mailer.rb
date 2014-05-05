class BillingMailer < MandrillMailer
  attr_reader :account

private
  def invoice_recipient
    payment_gateway = PaymentGateway.new(account.billing_provider_customer_id)
    payment_gateway.customer.presence.email || @account.users.first.email
  end

public
  def initialize(account)
    super
    @account = account
  end

  def autorecharge_failed
    text = BillingRender.new.autorecharge_failed(:text, account)
    send_email({
      :subject => "Autorecharge payment failed",
      :text => text,
      :from_name => 'Impact Dialing',
      :from_email => FROM_EMAIL,
      :to=>[{email: invoice_recipient}],
      :track_opens => true,
      :track_clicks => true
    })
  end

  def autorenewal_failed
    text = BillingRender.new.autorenewal_failed(:text, account)
    send_email({
      :subject => "Subscription renewal failed",
      :text => text,
      :from_name => 'Impact Dialing',
      :from_email => FROM_EMAIL,
      :to=>[{email: invoice_recipient}],
      :track_opens => true,
      :track_clicks => true
    })
  end
end
