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
    type.constantize.new
  end

  def number_of_days_in_current_month
    Time.days_in_month(DateTime.now.month, DateTime.now.year)
  end

  
  def available_minutes
    days_of_subscription = DateTime.now.mjd - subscription_start_date.to_date.mjd  
    (days_of_subscription <= number_of_days_in_current_month) ? (total_allowed_minutes - minutes_utlized) : -1
  end

  def renew
    self.subscription_start_date = DateTime.now
    self.total_allowed_minutes = calculate_minutes_on_upgrade
    self.minutes_utlized = 0
    self.save
  end

  def upgrade(new_plan)
    new_subscription = Subscription.subscription_type(new_plan)
    account.subscription = new_subscription    
    new_subscription.subscription_start_date = self.subscription_start_date
    new_subscription.number_of_callers = self.number_of_callers
    new_subscription.subscribe(available_minutes)
    new_subscription.save    
  end

  def add_callers(number_of_callers_to_add)
    self.number_of_callers = number_of_callers + number_of_callers_to_add    
    self.total_allowed_minutes +=  calculate_minute_on_add_callers(number_of_callers_to_add)
    self.save
  end

  def remove_callers(number_of_callers_to_remove)
    self.number_of_callers = number_of_callers - number_of_callers_to_remove
    self.save
  end

  def calculate_minutes_on_upgrade    
    days_remaining = number_of_days_in_current_month - (DateTime.now.mjd - subscription_start_date.to_date.mjd)
    (minutes_per_caller/number_of_days_in_current_month) * days_remaining * number_of_callers
  end

  def calculate_minute_on_add_callers(number_of_callers_to_add)
    days_remaining = number_of_days_in_current_month - (DateTime.now.mjd - subscription_start_date.to_date.mjd)
    (minutes_per_caller/number_of_days_in_current_month) * days_remaining * number_of_callers_to_add
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