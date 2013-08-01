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
    return available_minutes > 0
  end

  def subscription_type
    subscription_type = type + "Subscription"
    subscription_type.constantize.new
  end

  def available_minutes
    days_of_subscription = DateTime.now.mjd - subscription_start_date.mjd
    (days_of_subscription <= 31) ? (total_allowed_minutes - minutes_utlized) : 0
  end

end