module SubscriptionInfo

  module ClassMethods
  end

  module InstanceMethods
  def current_subscription        
    subscriptions.detect{|x|  Subscription::Status::CURRENT.include?(x.status)}
  end

  def current_subscriptions    
    subscriptions.select{|x| Subscription::Status::CURRENT.include?(x.status)}
  end

  def debitable_subscription
    current_subscriptions.detect{|x| x.subscription_end_date > DateTime.now.utc}
  end

  def minutes_utlized
    active_subscriptions = subscriptions.select{|x| x.subscription_end_date > DateTime.now.utc}
    active_subscriptions.map(&:minutes_utlized).inject(0, &:+)
  end


 end
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

end
