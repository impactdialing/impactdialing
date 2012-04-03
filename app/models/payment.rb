class Payment < ActiveRecord::Base
  belongs_to :account

  def self.debit (call_time, model_instance)
    return false if model_instance.payment_id!=nil
    account = model_instance.campaign.account
    return false if account.active_subscription=="manual"
    debit_amount = call_time.to_f * Payment.determine_call_cost(model_instance)
    payment_used = Payment.where("amount_remaining > 0 and account_id = ?", account).last
    return false if payment_used.nil? #hmmm
      
    payment_used.amount_remaining -= debit_amount
    payment_used.save
    model_instance.payment_id=payment_used.id
    model_instance.save
    
    account.check_autorecharge(payment_used.amount_remaining)
    payment_used
  end
  
  def self.determine_call_cost(model_instance)
    
    return 0.02 if model_instance.campaign.account.active_subscription=="Per Caller"

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

    
  
  def self.charge_recurly_account(account, amount, notes)
#    begin
      recurly_account = Recurly::Account.find(account.recurly_account_code)
      transaction = recurly_account.transactions.create(
        :description     => notes,
        :amount_in_cents => (amount.to_f*100).to_i,
        :currency        => 'USD',
        :account         => { :account_code => account.recurly_account_code }
      )
      
      if transaction.status=="success"
        p = Payment.new(:amount_paid=>amount, :amount_remaining=>amount, :account_id=>account.id, :notes=>notes, :recurly_transaction_uuid=>transaction.uuid)
        p.save
        return p
      else
        return nil
      end
      
#    rescue
#      return nil
#    end
  end

end
