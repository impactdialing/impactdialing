class Billing::Subscription < ActiveRecord::Base
  serialize :settings, HashWithIndifferentAccess

  belongs_to :account

  validates_presence_of :account, :plan
  validates_inclusion_of :plan, in: ::Billing::Plans.list

  validate :sane_autorecharge_settings
  validate :sane_contract_settings

private
  def autorecharge_defaults
    {enabled: 0, trigger: 0, amount: 0, pending: 0}
  end

  def contract_defaults
    {price_per_quantity: nil}
  end

  def sane_autorecharge_settings
    return if not autorecharge_active?

    unless autorecharge_trigger > 0 && autorecharge_amount > 0
      errors.add(:base, I18n.t('subscriptions.autorecharge.invalid_settings'))
    end
  end

  def sane_contract_settings
    return if _contract == contract_defaults

    unless contract.valid?
      errors.add(:base, I18n.t('subscriptions.contract.invalid_settings'))
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

    provider_start_period != start_period && provider_end_period != end_period
  end

  Contract = Struct.new(:_price_per_quantity) do
    def valid?
      (n = _price_per_quantity).blank? or
      (n.to_f <= 0.10 and n.to_f >= 0.02)
    end

    def price_per_quantity
      _price_per_quantity.blank? ? nil : _price_per_quantity.to_f
    end
  end
  def contract
    @contract ||= Contract.new(_contract[:price_per_quantity])
  end

  def _contract
    settings[:contract].blank? ? contract_defaults : settings[:contract]
  end

  def update_contract(new_settings)
    @contract = nil
    self.settings[:contract] = _contract.merge new_settings
  end

  def update_contract!(new_settings)
    update_contract(new_settings)
    save!
  end

  def price_per_quantity
    contract.price_per_quantity || plans.find('per_minute').price_per_quantity
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
    return 0 unless current_plan.per_minute?

    (autorecharge_amount.to_i / price_per_quantity.to_f).to_i
  end

  def autorecharge_pending!
    update_autorecharge_settings!({pending: 1})
  end

  def autorecharge_paid!
    update_autorecharge_settings!({pending: 0})
  end

  def autorecharge_disable!
    update_autorecharge_settings!({enabled: 0, pending: 0})
  end

  def update_autorecharge_settings(new_settings)
    new_settings = autorecharge_settings.merge(new_settings)
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

# ## Schema Information
#
# Table name: `billing_subscriptions`
#
# ### Columns
#
# Name                         | Type               | Attributes
# ---------------------------- | ------------------ | ---------------------------
# **`id`**                     | `integer`          | `not null, primary key`
# **`account_id`**             | `integer`          | `not null`
# **`provider_id`**            | `string(255)`      |
# **`provider_status`**        | `string(255)`      |
# **`plan`**                   | `string(255)`      | `not null`
# **`settings`**               | `text`             |
# **`created_at`**             | `datetime`         | `not null`
# **`updated_at`**             | `datetime`         | `not null`
# **`provider_start_period`**  | `integer`          |
# **`provider_end_period`**    | `integer`          |
#
# ### Indexes
#
# * `index_billing_subscriptions_on_account_id`:
#     * **`account_id`**
# * `index_billing_subscriptions_on_provider_id`:
#     * **`provider_id`**
#
