class Billing::Subscription < ActiveRecord::Base
  attr_accessible :account_id, :plan, :provider_status, :provider_id
  serialize :settings, HashWithIndifferentAccess

  belongs_to :account

  validates_presence_of :account, :plan
  validates_inclusion_of :plan, in: ::Billing::Plans.list

  validate :sane_autorecharge_settings

  # todo: validate inclusion of plan,
  # must be one of 'per_minute', 'enterprise', 'business', 'basic' or 'pro'
private
  def autorecharge_defaults
    {enabled: 0, trigger: 0, amount: 0, pending: 0}
  end

  def sane_autorecharge_settings
    return if not autorecharge_active?

    unless autorecharge_trigger > 0 && autorecharge_amount > 0
      errors.add(:base, I18n.t('subscriptions.autorecharge.invalid_settings'))
    end
  end

public
  def plans
    @plans ||= Billing::Plans.new
  end

  def current_plan
    @current_plan ||= plans.find(plan)
  end

  def trial?
    return plans.is_trial?(plan)
  end

  def enterprise?
    return plans.is_enterprise?(plan)
  end

  def per_minute?
    return plans.is_per_minute?(plan)
  end

  def canceled?
    return provider_status == 'canceled'
  end

  ##
  #
  # Returns true if +provider_status+ == 'active' or
  # one of +trial?+, +enterprise?+, or +per_minute?+
  # return true.
  #
  # Trial, Per minute & Enterprise accounts are considered as always
  # active because they:
  # - never expire
  # - have no corresponding plan in stripe, so provider_status will be nil
  #
  def active?
    return trial? || enterprise? || per_minute? || provider_status == 'active'
  end

  def autorecharge_active?
    autorecharge_settings[:enabled].to_i > 0
  end

  def autorecharge_pending?
    autorecharge_pending.to_i > 0
  end

  def is_renewal?(start_period, end_period)
    return false if provider_start_period.blank? || provider_end_period.blank?

    # Bypass any minor time diffs between us and Stripe.
    required_diff = 25.days
    (provider_start_period - start_period).abs > required_diff &&
    (provider_end_period - end_period).abs > required_diff
  end

  def autorecharge_settings
    settings[:autorecharge] || autorecharge_defaults
  end

  def autorecharge_amount
    autorecharge_settings[:amount].to_i
  end

  def autorecharge_trigger
    autorecharge_settings[:trigger].to_i
  end

  def autorecharge_pending
    autorecharge_settings[:pending].to_i
  end

  def autorecharge_minutes
    current_plan.calculate_purchased_minutes(autorecharge_amount)
  end

  def autorecharge_pending!
    new_settings = autorecharge_settings.merge({pending: 1})
    update_autorecharge_settings!(new_settings)
  end

  def autorecharge_paid!
    new_settings = autorecharge_settings.merge({pending: 0})
    update_autorecharge_settings!(new_settings)
  end

  def autorecharge_disable!
    new_settings = autorecharge_settings.merge({enabled: 0, pending: 0})
    update_autorecharge_settings!(new_settings)
  end

  def update_autorecharge_settings(new_settings)
    self.settings[:autorecharge] = new_settings
  end

  def update_autorecharge_settings!(new_settings)
    update_autorecharge_settings(new_settings)
    save!
  end

  def cache_provider_status!(status)
    self.provider_status = status
    save!
  end

  def cache_provider_details(provider_id, start_period, end_period, status)
    start_period               = start_period.blank? ? nil : Time.at(start_period)
    end_period                 = end_period.blank? ? nil : Time.at(end_period)
    self.provider_start_period = start_period
    self.provider_end_period   = end_period
    self.provider_status       = status
    self.provider_id           = provider_id
  end

  def update_plan(new_plan)
    self.plan = new_plan
  end

  def renewed!(start_period, end_period, status)
    start_period               = start_period.blank? ? nil : Time.at(start_period)
    end_period                 = end_period.blank? ? nil : Time.at(end_period)
    self.provider_start_period = start_period
    self.provider_end_period   = end_period
    self.provider_status       = status
    save!
  end

  ##
  # Update +plan+, +provider_id+ and +provider_status+ as needed when a plan changes.
  # Used for both recurring and per minute plans. Applicable during
  # upgrades/downgrades, when callers are added/removed to recurring plans
  # and when minutes are added to per minute plans.
  #
  def plan_changed!(new_plan, provider_object=nil, opts={})
    plan  = plans.find(new_plan)

    update_plan(new_plan)

    if plan.presence.recurring?
      cache_provider_details(provider_object.id, provider_object.current_period_start, provider_object.current_period_end, provider_object.status)
      update_autorecharge_settings(autorecharge_defaults)
    else
      cache_provider_details(nil, nil, nil, nil)
    end

    save!
  end

  def plan_cancelled!(provider_object)
    cache_provider_details(provider_object.id, provider_object.current_period_start, provider_object.current_period_end, provider_object.status)
    update_autorecharge_settings(autorecharge_defaults)
    save!
  end
end

# module Status
#   TRIAL = "Trial"
#   UPGRADED = "Upgraded"
#   DOWNGRADED = "Downgraded"
#   CALLERS_ADDED = "Callers Added"
#   CALLERS_REMOVED = "Callers Removed"
#   SUSPENDED = "Suspended"
#   CANCELED = "Canceled"
#   CURRENT = [TRIAL,UPGRADED,DOWNGRADED,CALLERS_ADDED,CALLERS_REMOVED]
# end