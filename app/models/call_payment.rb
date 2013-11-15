module CallPayment
  module ClassMethods; end

  module InstanceMethods
    def debit
      if skip_debit?
        self.debited = true
        alert_if_missing_subscription
      else
        self.debited = debitable_subscription.debit(call_time)
      end
      return self
    end

    def skip_debit?
      call_not_connected? || debitable_subscription.nil?
    end

    def debitable_subscription
      @debitable_subscription ||= _account.debitable_subscription
    end

    def _account
      @_account ||= campaign.account
    end

    def alert_if_missing_subscription
      if debitable_subscription.nil?
        subject = "nil debitable subscription"
        msg = "Account[#{_account.id}]\n#{self.class}[#{self.id}]\nCall time: #{call_time}"
        UserMailer.new.alert_email(subject, msg)
      end
    end
  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
end
