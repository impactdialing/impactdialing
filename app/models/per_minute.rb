class PerMinute < Subscription
  validates_numericality_of :amount_paid, greater_than: 0

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

  def can_dial?
    available_minutes > 0
  end


  def debit(call_time)
    if autorecharge_enabled && ((account.available_minutes * 0.09) < autorecharge_trigger)
      begin
        PerMinute.recharge_subscription(account.id, autorecharge_amount)
      rescue
        account.subscriptions.update_all(autorecharge_enabled: false)
      end
    end
    updated_minutes = minutes_utlized + call_time
    self.update_attributes(minutes_utlized: updated_minutes)
  end

  def calculate_minutes_on_upgrade()
    amount_paid.to_f/0.09
  end

  def subscribe(upgrade=true)
    self.total_allowed_minutes = calculate_minutes_on_upgrade()
  end

  def self.recharge_subscription(account_id, amount)
    account = Account.find(account_id)
    subscription = account.current_subscription
    new_subscription = PerMinute.new(status: Subscription::Status::UPGRADED, account_id: account.id, amount_paid: amount.to_i,
      stripe_customer_id: subscription.stripe_customer_id, subscription_start_date: DateTime.now,
      subscription_end_date: DateTime.now+1.year)
    charge = new_subscription.recharge
    new_subscription.subscribe
    new_subscription.save
    new_subscription.update_charge_info(charge)
    new_subscription
  end

  def self.configure_autorecharge(account_id, autorecharge_enabled, autorecharge_amount, autorecharge_trigger)
    account = Account.find(account_id)
    account.subscriptions.update_all(autorecharge_enabled: autorecharge_enabled, autorecharge_amount: autorecharge_amount,
      autorecharge_trigger: autorecharge_trigger)
  end

  def create_customer(token, email, plan_type, number_of_callers, amount)
    create_customer_charge(token, email, amount.to_i*100)
  end


end