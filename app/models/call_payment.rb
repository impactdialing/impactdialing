module CallPayment
  
  module ClassMethods    
  end
  
  module InstanceMethods
    
    def debit
      account = campaign.account
      if call_not_connected? || !payment_id.nil? || account.manual_subscription?
        self.debited = true 
        # update_attribute(:debited, true)
        return self
      end
      payment = Payment.where("amount_remaining > 0 and account_id = ?", account).last
      if payment.nil?      
        payment = account.check_autorecharge(account.current_balance)
      end      
      unless payment.nil?              
        payment.debit_call_charge(amount_to_debit, account)
        self.payment_id = payment.try(:id)
        self.debited = true
        # self.update_attributes(payment_id: payment.try(:id))
        # self.update_attribute(:debited, true)
        account.check_autorecharge(account.current_balance)        
      end
      return self
    end
    
    def amount_to_debit
      call_time.to_f * determine_call_cost
    end
    
    def determine_call_cost
      return 0.02 if campaign.account.per_caller_subscription?      
      campaign.cost_per_minute
    end
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end