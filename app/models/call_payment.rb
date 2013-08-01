module CallPayment

  module ClassMethods
  end

  module InstanceMethods

    def debit
      account = campaign.account
      if call_not_connected? || !payment_id.nil?
        self.debited = true
        return self
      end
      self.debited = account.subscription.debit(call_time)
      return self
    end

  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

end