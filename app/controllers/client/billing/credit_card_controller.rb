##
# @account is inherited from +ClientController#check_login+.
#
class Client::Billing::CreditCardController < ClientController

  rescue_from Stripe::CardError, with: :flash_error_and_render_show

private
  def flash_error_and_render_show(exception)
    flash.now[:error] = [exception.message]
    render :show and return
  end

  def credit_card
    validate_account_presence!(@account) || return
    @credit_card ||= @account.billing_credit_card
  end

  def email
    @account.users.find(invoice_recipient_id).try(:email)
  end

  def invoice_recipient_id
    params[:invoice_recipient_id]
  end

  def token
    params[:stripeToken]
  end

public
  def show
    if credit_card.nil?
      @credit_card = @account.build_billing_credit_card
    end
    payment_gateway    = Billing::PaymentGateway.new(@account.billing_provider_customer_id)
    @invoice_recipient = @account.users.find_by_email(payment_gateway.customer.email)
  end

  def create
    @account.build_billing_credit_card.update_or_create_customer_and_card(email, token)
    flash_message(:notice, I18n.t('subscriptions.update_billing.success'))
    redirect_to client_billing_subscription_path
  end

  def update
    credit_card.update_or_create_customer_and_card(email, token)
    flash_message(:notice, I18n.t('subscriptions.update_billing.success'))
    redirect_to client_billing_subscription_path
  end

  def destroy
  end
end
