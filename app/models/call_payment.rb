module CallPayment
  
  module ClassMethods    
  end
  
  module InstanceMethods
    
    def debit
      account = campaign.account
      return  if call_not_connected? || !payment_id.nil? || account.manual_subscription?
      payment = Payment.where("amount_remaining > 0 and account_id = ?", account).last
      return if payment.nil?      
      payment.debit_call_charge(amount_to_debit, account)
      self.update_attributes(payment_id: payment.try(:id))
      account.check_autorecharge(payment.amount_remaining)
    end
    
    def amount_to_debit
      call_time.to_f * determine_call_cost
    end
    
    def determine_call_cost
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