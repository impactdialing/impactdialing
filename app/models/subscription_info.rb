module SubscriptionInfo

  module ClassMethods
  end

  module InstanceMethods

  def current_subscription        
    subscriptions.detect{|x|  Subscription::Status::CURRENT.include?(x.status)} || subscriptions.detect{|x|  x.type == Subscription::Type::TRIAL}
  end

  def current_subscriptions    
    subscriptions.select{|x| Subscription::Status::CURRENT.include?(x.status)}
  end

  def debitable_subscription
    current_subscriptions.detect{|x| x.subscription_end_date > DateTime.now.utc}
  end

  def minutes_utlized
    active_subscriptions = current_subscriptions.select{|x| x.subscription_end_date > DateTime.now.utc}
    active_subscriptions.map(&:minutes_utlized).inject(0, &:+)
  end

  def available_minutes
    active_subscriptions = current_subscriptions.select{|x| x.subscription_end_date > DateTime.now.utc}
    active_subscriptions.map(&:total_allowed_minutes).inject(0, &:+) - minutes_utlized
  end

  def number_of_callers
    active_subscriptions = current_subscriptions.select{|x| x.subscription_end_date > DateTime.now.utc}
    active_subscriptions.map(&:number_of_callers).inject(0, &:+)
  end

  def per_minute_subscription?
    current_subscription.type == Subscription::Type::PER_MINUTE
  end

  def manual_subscription?
    current_subscription.type == Subscription::Type::ENTERPRISE
  end

  def per_caller_subscription?
    current_subscription.per_agent?
  end

  def subscription_allows_caller?
    if per_minute_subscription? || manual_subscription?
      return true
    elsif per_caller_subscription? && self.callers_in_progress.length <= Subscription.active_number_of_callers(self.id)
      return true
    else
      return false
    end
  end



 end
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

end
