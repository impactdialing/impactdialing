class Subscription < ActiveRecord::Base
  include SubscriptionProvider
  belongs_to :account
  validate :minutes_utlized_less_than_total_allowed_minutes
  validates :number_of_callers, numericality: { greater_than:  0}, :if => Proc.new{|subscription| subscription.per_agent? }
  
  

  module Type
    TRIAL = "Trial"
    BASIC = "Basic"
    PRO = "Pro"
    BUSINESS = "Business"
    PER_MINUTE = "PerMinute"
    ENTERPRISE = "Enterprise"
    PAID_SUBSCRIPTIONS = [BASIC,PRO,BUSINESS, PER_MINUTE]
  end

  module Status
    TRIAL = "Trial"
    ACTIVE = "Active"
    SUSPENDED = "Suspended"
    CANCELED = "Canceled"
  end

  def activated?
    type == Type::TRIAL || status == Status::ACTIVE
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

  

  def stripe_plan_id
    "ImpactDialing-" + type
  end

  def self.stripe_plan_id(type)
    "ImpactDialing-" + type
  end

  

  def upgrade(new_plan, num_of_callers=1, amount=0)    
    self.type = new_plan
    self.number_of_callers = num_of_callers
    self.save
    if new_plan == Type::PER_MINUTE
      account.subscription.subscribe(minutes, amount)
    else
      account.subscription.subscribe
    end
    account.subscription.save    
  end
  
  def update_info(customer)    
    card_info = customer.cards.data.first
    account.subscription.update_attributes(stripe_customer_id: customer.id, cc_last4: card_info.last4, exp_month: card_info.exp_month, 
    exp_year: card_info.exp_year)      
  end

  def recharge_subscription(amount)
    recharge(amount)
    subscribe(available_minutes, amount)
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

  def disable_call_recording
    account.update_attributes(record_calls: false)
  end

  def card_info
    unless cc_last4.nil?
      "xxxx xxxx xxxx " + cc_last4
    end
  end

  def cancelled?
    status == Status::CANCELED
  end

  def cancel
    cancel_subscription
    self.update_attributes(status: Status::CANCELED, stripe_customer_id: nil, cc_last4: nil, exp_year: nil, exp_month: nil)
  end
  

end