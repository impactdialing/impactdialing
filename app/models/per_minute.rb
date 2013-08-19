class PerMinute < Subscription

  def campaign_types
    [Campaign::Type::PREVIEW, Campaign::Type::POWER, Campaign::Type::PREDICTIVE]
  end

  def campaign_type_options
    [[Campaign::Type::PREVIEW, Campaign::Type::PREVIEW], [Campaign::Type::POWER, Campaign::Type::POWER], [Campaign::Type::PREDICTIVE, Campaign::Type::PREDICTIVE]]
  end

  def transfer_types
    [Transfer::Type::WARM, Transfer::Type::COLD]
  end

  def caller_groups_enabled?
    true
  end

  def campaign_reports_enabled?
    true
  end

  def caller_reports_enabled?
    true
  end

  def call_recording_enabled?
    true
  end

  def dashboard_enabled?
    true
  end

  def debit(call_time)
    payment = Payment.where("amount_remaining > 0 and account_id = ?", account).last
  end

  def calculate_minutes_on_upgrade(amount)
    amount.to_f/0.09
  end

  def upgrade(new_plan, num_of_callers=1, amount=0)                
    account.subscription.subscribe(amount)
    account.subscription.save    
  end


  def subscribe(amount, old_available_minutes=0)        
    self.total_allowed_minutes = calculate_minutes_on_upgrade(amount) + old_available_minutes
  end

  def recharge_subscription(amount)
    recharge(amount)
    subscribe(amount, total_allowed_minutes)
    self.save
  end

  def create_customer(token, email, plan_type, number_of_callers, amount)
    create_customer_charge(token, email, amount)
  end

  def create_subscription(token, email, plan_type, number_of_callers, amount)
    upgrade(plan_type, number_of_callers, amount)
    begin
      customer = create_customer(token, email, plan_type, number_of_callers, amount)
      update_info(plan_type, number_of_callers, amount)
    rescue
      errors.add(:base, e.message)
    end
    
  end

  def upgrade_subscription(token, email, plan_type, number_of_callers, amount)
    change_subscription_type(plan_type)
    account.subscription.upgrade(plan_type, number_of_callers, amount)
    begin
      recharge(amount)    
    rescue
      errors.add(:base, e.message)
    end
  end

end