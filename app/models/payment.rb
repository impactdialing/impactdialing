class Payment < ActiveRecord::Base
  belongs_to :account

  module PaymentTypes
    PROMO = "Promotional credit"
    RECURLY = "Charged through Recurly"
    RECURLY_REFUND = "Refunded through Recurly"
  end


  def self.add_call (model_instance)
    return false if model_instance.payment_id!=nil || model_instance.tPrice.nil?
    account = model_instance.campaign.account_id
    payment_used = Payment.where("amount_remaining > 0 and account_id = ?", account).last
    payment_used.amount_remaining -= model_instance.tPrice.abs
    payment_used.save
    model_instance.invoice_id=payment_id.id
    model_instance.save
  end
  
  def self.charge_recurly_account(recurly_account_code, amount, notes)
#    begin
      account = Recurly::Account.find(recurly_account_code)
      transaction = account.transactions.create(
        :description     => notes,
        :amount_in_cents => (amount.to_f*100).to_i,
        :currency        => 'USD',
        :account         => { :account_code => recurly_account_code }
      )
      transaction.status=="success" ? transaction.uuid : nil
#    rescue
#      return nil
#    end
  end

end
