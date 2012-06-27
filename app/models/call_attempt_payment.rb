module CallAttemptPayment
  
  module ClassMethods
    
  end
  
  module InstanceMethods
    
    def debit
      return  if call_not_connected? || payment_id.nil?
      account = campaign.account
      return if account.manual_subscription?
      Payment.debit_call_charge(amount_to_debit)
      # account.check_autorecharge(payment_used.amount_remaining)
      account.check_autorecharge()
    end
    
    def amount_to_debit
      debit_amount = call_time.to_f * determine_call_cost
    end
    
    def self.determine_call_cost
      return 0.02 if campaign.account.per_caller_subscription?      
      campaign.cost_per_minute
    end
    
    
    def call_not_connected?
      connecttime.nil? || call_end.nil?
    end
    
    def call_time
    ((call_end - connecttime)/60).ceil
    end
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end