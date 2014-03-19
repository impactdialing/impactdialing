class Billing::CreditCard < ActiveRecord::Base
  attr_accessible :account_id, :exp_month, :exp_year, :last4, :provider_id

  belongs_to :account

  validates_presence_of :account

private
  def payment_gateway
    @payment_gateway ||= Billing::PaymentGateway.new(account.billing_provider_customer_id)
  end

public
  def update_or_create_customer_and_card(email, token)
    if account.billing_provider_customer_id.present?
      gateway_customer = payment_gateway.update_customer_and_card(email, token)
    else
      # what will stripe do if we try to create a customer w/ an email that already exists
      # on a customer? A: stripe will create the customer w/ a duplicate email.
      gateway_customer = payment_gateway.create_customer_with_card(email, token)
      # notify the account of the new stripe customer id
      account.billing_provider_customer_created!(gateway_customer.id)
    end
  end
end
