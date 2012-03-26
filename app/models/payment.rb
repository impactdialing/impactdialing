class Payment < ActiveRecord::Base
  belongs_to :account

  module PaymentTypes
    PROMO = "Promotional credit"
    RECURLY = "Charged through Recurly"
    RECURLY_REFUND = "Refunded through Recurly"
  end


  def self.debit (model_instance, account)
    return false if model_instance.endtime.nil? || model_instance.starttime.nil?
    call_time = ((model_instance.endtime - model_instance.starttime)/60).ceil
    debit_amount = call_time.to_f * 0.02
    payment_used = Payment.where("amount_remaining > 0 and account_id = ?", account).last
    if payment_used.nil?
    else
      payment_used.amount_remaining -= debit_amount
      payment_used.save
      model_instance.payment_id=payment_used.id
      model_instance.save
    end
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
