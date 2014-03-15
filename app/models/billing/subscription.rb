class Billing::Subscription < ActiveRecord::Base
  attr_accessible :account_id, :plan, :provider_status, :provider_id
  serialize :settings, HashWithIndifferentAccess

  belongs_to :account

  validates_presence_of :account, :plan

  validate :sane_autorecharge_settings

  # todo: validate inclusion of plan,
  # must be one of 'per_minute', 'enterprise', 'business', 'basic' or 'pro'
private
  def autorecharge_defaults
    {enabled: 0, trigger: 0, amount: 0}
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
    return plans.is_trial?(plan.underscore)
  end

  def canceled?
    return status == 'Canceled'
  end

  def autorecharge_active?
    autorecharge_settings[:enabled].to_i > 0
  end

  def autorecharge_settings
    settings[:autorecharge] || autorecharge_defaults
  end

  def autorecharge_amount
    (autorecharge_settings[:amount] || 0).to_i
  end

  def autorecharge_trigger
    (autorecharge_settings[:trigger] || 0).to_i
  end

  def autorecharge_minutes
    current_plan.calculate_purchased_minutes(autorecharge_amount)
  end

  def update_autorecharge_settings!(new_settings)
    self.settings[:autorecharge] = new_settings
    save!
  end

  ##
  # Update +plan+, +provider_id+ and +provider_status+ as needed when a plan changes.
  # Used for both recurring and per minute plans. Applicable during
  # upgrades/downgrades, when callers are added/removed to recurring plans
  # and when minutes are added to per minute plans.
  #
  def plan_changed!(new_plan, provider_object, opts={})
    plan  = plans.find(new_plan)

    new_attrs = if plan.recurring?
                  {
                    plan: new_plan,
                    provider_id: provider_object.id,
                    provider_status: provider_object.status
                  }
                else
                  {
                    plan: new_plan,
                    provider_id: nil,
                    provider_status: nil
                  }
                end

    update_attributes!(new_attrs)
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