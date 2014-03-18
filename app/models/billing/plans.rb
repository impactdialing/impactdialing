##
# Keep order among plans. Plan data is loaded from
# `config/subscription_plans.yml`. This class provides
# convenience methods around plans to aid in making
# workflow decisions.
#
class Billing::Plans
  RECURRING_PLANS = ['basic', 'pro', 'business']

private
  def valid_recurring?(new_plan, callers_allowed=nil)
    recurring?(new_plan) &&
    present_and_positive?(callers_allowed)
  end
  def valid_minutes_purchase?(new_plan, amount_paid=nil)
    buying_minutes?(new_plan) &&
    present_and_positive?(amount_paid)
  end
  def blank_or_not_positive?(var)
    var.blank? || var.to_i <= 0
  end
  def present_and_positive?(var)
    !blank_or_not_positive?(var)
  end

public
  ##
  # Raised whenever the provided plan does not pass
  # sanity checks for the provided opts. Recurring plans
  # require the `:callers_allowed` opt to be some Int > 0.
  # Per minute or pay as you go plans require the `:amount_paid`
  # opt to be some Float > 0.
  #
  class InvalidPlanTransition < ArgumentError
    attr_reader :old_plan, :new_plan, :opts, :message

    def initialize(old_plan, new_plan, opts, msg)
      @old_plan = old_plan
      @new_plan = new_plan
      @opts     = opts
      @message  = msg
    end
  end

  def initialize
    @config = SUBSCRIPTION_PLANS
  end

  def self.permitted_ids_for(plan_id, minutes_available)
    this = self.new
    plan = this.find(plan_id)
    ids.reject do |id|
      !this.valid_transition?(false, plan_id, id, minutes_available, {callers_allowed: 1, amount_paid: 3})
    end
  end

  def self.ids
    self.new.ids
  end

  def find(plan_id)
    attrs = @config[plan_id]
    Plan.new(plan_id, attrs)
  end

  def ids
    @config.keys
  end

  def list
    ['trial'] + ids + ['enterprise']
  end

  ##
  # Relies on the order of the keys and that the last key
  # is the most valuable plan. Returns true if old_plan
  # is of lesser value than new_plan.
  #
  def is_upgrade?(old_plan_id, new_plan_id)
    new_n = list.index(new_plan_id)
    old_n = list.index(old_plan_id)
    return is_enterprise?(new_plan_id) ||
          (new_n.present? && old_n.present? && new_n > old_n)
  end

  def is_trial?(plan_id)
    return plan_id == 'trial'
  end

  def is_enterprise?(plan_id)
    self.class.is_enterprise?(plan_id)
  end

  def self.is_enterprise?(plan_id)
    return plan_id == 'enterprise'
  end

  ##
  # Returns true if plan is `per_minute` and amount_paid is
  # some whole number greater than zero.
  #
  def buying_minutes?(plan_id)
    plan = find(plan_id)
    return plan.presence.per_minute?
  end

  ##
  # Returns true if the given plan matches any
  # of the plans in +RECURRING_PLANS+.
  #
  def recurring?(plan_id)
    plan = find(plan_id)
    return plan.presence.recurring?
  end

  ##
  # Raises +Billing::Plans::InvalidPlanTransition+ when the requested plan change
  # cannot be performed.
  #
  # Returns true otherwise.
  #
  # old_plan and new_plan should be strings matching an item in +list+.
  # minutes_available should be boolean: true indicates there are minutes
  # available for use on the account.
  # opts is a hash where valid keys are :callers_allowed & :amount_paid and valid
  # values are positive integer or float values (both will be treated as Integer).
  #
  def validate_transition!(old_plan, new_plan, minutes_available, opts={})
    msg = valid_transition?(true, old_plan, new_plan, minutes_available, opts)
    msg = I18n.t(msg)
    raise InvalidPlanTransition.new(old_plan, new_plan, opts, msg)
  end

  def valid_transition?(return_msg, old_plan, new_plan, minutes_available, opts={})
    msg = if recurring?(new_plan) && !valid_recurring?(new_plan, opts[:callers_allowed])
            'billing.plans.transition_errors.callers_allowed'
          elsif buying_minutes?(new_plan)
            if recurring?(old_plan) && minutes_available
              'billing.plans.transition_errors.minutes_available'
            elsif !valid_minutes_purchase?(new_plan, opts[:amount_paid])
              'billing.plans.transition_errors.amount_paid'
            end
          end

    return true if msg.blank?
    return msg if return_msg
    return false
  end
end

##
# Convenient wrapper of yaml loaded plan objects.
#
class Billing::Plans::Plan
  attr_reader :id, :minutes_per_quantity, :price_per_quantity
  # hash = {'price_per' => 199, 'quantity_per' => 1}
  def initialize(id, hash)
    hash ||= {}
    @id                   = id
    @minutes_per_quantity = hash['minutes_per_quantity']
    @price_per_quantity   = hash['price_per_quantity']
  end

  def recurring?
    return Billing::Plans::RECURRING_PLANS.include?(id)
  end

  def enterprise?
    Plans.is_enterprise?(id)
  end

  def per_minute?
    id == 'per_minute'
  end

  def calculate_purchased_minutes(amount_paid)
    return 0 unless per_minute?
    (amount_paid.to_i / 0.09).to_i
  end
end
