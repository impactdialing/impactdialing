class Subscription < ActiveRecord::Base
  belongs_to :account
  validate :minutes_utlized_less_than_total_allowed_minutes

  module Type
    TRIAL = "Trial"
    BASIC = "Basic"
    PRO = "Pro"
    BUSINESS = "Business"
    PER_MINUTE = "PerMinute"
    ENTERPRISE = "Enterprise"
  end

  def minutes_utlized_less_than_total_allowed_minutes
    if minutes_utlized_changed? && available_minutes < 0
      errors.add(:base, 'You have consumed all your minutes for your subscription')
    end
  end

  def self.subscription_type(type)
    subscription_type_constant(type).constantize.new
  end

  def self.subscription_type_constant(type)
    type + "Subscription"
  end

  def available_minutes
    days_of_subscription = DateTime.now.mjd - subscription_start_date.to_date.mjd
    (days_of_subscription <= 31) ? (total_allowed_minutes - minutes_utlized) : -1
  end

  def upgrade(new_plan)
    new_subscription = Subscription.subscription_type(new_plan)
    total_minutes = new_subscription.minutes_per_caller * number_of_callers
    self.type = new_subscription.type
    self.subscription_start_date =  DateTime.now
    self.total_allowed_minutes = total_minutes
    self.save
  end

  def trial?
    type == Type::TRIAL
  end

  def per_agent?
    [Type::TRIAL, Type::BASIC, Type::PRO, Type::BUSINESS].include?(type)
  end

  def per_minute?
    type == Type::PER_MINUTE
  end

end