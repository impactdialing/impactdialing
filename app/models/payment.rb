class Payment < ActiveRecord::Base
  belongs_to :account

  module PaymentTypes
    PROMO = "Promotional credit"
    RECURLY = "Charged through Recurly"
    RECURLY_REFUND = "Refunded through Recurly"
  end


  def self.debit (call_time, model_instance)
    return false if model_instance.payment_id!=nil
    account = model_instance.campaign.account
    debit_amount = call_time.to_f * Payment.determine_call_cost(model_instance)
    payment_used = Payment.where("amount_remaining > 0 and account_id = ?", account).last
    if payment_used.nil?
      account.auto_recharge
    else
      payment_used.amount_remaining -= debit_amount
      payment_used.save
      model_instance.payment_id=payment_used.id
      model_instance.save
    end
  end
  
  def self.determine_call_cost(model_instance)

    #4 robo
    #7 interactive robo
    #9 predictive/live
    #9 caller (client free)
    #(7 power, 5 preview) no longer used


    if model_instance.class==CallAttempt && model_instance.campaign.robo?
      if model_instance.campaign.script==nil || model_instance.campaign.script.result_set_1.nil?
        return 0.04
      else
        return 0.07
      end
    end

    return 0.09

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
