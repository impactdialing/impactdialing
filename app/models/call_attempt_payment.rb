module CallAttemptPayment
  
  module ClassMethods
    
  end
  
  module InstanceMethods
    
    def debit
      return  if call_not_connected? || payment_id.nil?
      account = campaign.account
      # return if account.active_subscription=="manual"
      # debit_amount = call_time.to_f * Payment.determine_call_cost(self)
      # payment_used = Payment.where("amount_remaining > 0 and account_id = ?", account).last
      # return if payment_used.nil? #hmmm we're running negative
      # 
      # payment_used.amount_remaining -= debit_amount
      # payment_used.save
      # payment_id=payment_used.id
      # self.save
      # account.check_autorecharge(payment_used.amount_remaining)
      # payment_used      
      Payment.debit(call_time, self)
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