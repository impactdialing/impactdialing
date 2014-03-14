##
# Keep order among plans. Plan data is loaded from
# `config/subscription_plans.yml`. This class provides
# convenience methods around plans to aid in making
# workflow decisions.
#
class Billing::Plans
  RECURRING_PLANS = ['basic', 'pro', 'business']

private
  def valid_recurring?(old_plan, new_plan, minutes_available, callers_allowed=nil)
    recurring?(new_plan) &&
    callers_allowed.present? &&
    callers_allowed.to_i > 0 &&
    (recurring?(old_plan) || !minutes_available)
  end
  def valid_minutes_purchase?(plan, amount_paid=nil)
    buying_minutes?(plan) &&
    amount_paid.present? &&
    amount_paid.to_i > 0
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
    attr_reader :plan, :opts, :record

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

  def find(plan_id)
    attrs = @config[plan_id]
    Plan.new(plan_id, attrs)
  end

  def list
    ['trial'] + @config.keys + ['enterprise']
  end

  ##
  # Relies on the order of the keys and that the last key
  # is the most valueable plan. Returns true if old_plan
  # is of lesser value than new_plan.
  #
  def is_upgrade?(old_plan_id, new_plan_id)
    new_n = list.index(new_plan_id)
    old_n = list.index(old_plan_id)
    return new_n.present? && old_n.present? && new_n > old_n
  end

  def is_trial?(plan_id)
    return plan_id == 'trial'
  end

  ##
  # Returns true if plan is `per_minute` and amount_paid is
  # some whole number greater than zero.
  #
  def buying_minutes?(plan_id)
    return plan_id == 'per_minute'
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
    msg = ""
    if recurring?(new_plan) && !valid_recurring?(old_plan, new_plan, minutes_available, opts[:callers_allowed])
      if opts[:callers_allowed].blank? || opts[:callers_allowed].to_i <= 0
        msg = "Please enter a number of callers greater than zero."
      elsif buying_minutes?(old_plan) && minutes_available
        msg = "Please use all of your purchased minutes before moving to a regularly recurring subscription."
      end
    elsif buying_minutes?(new_plan) && !valid_minutes_purchase?(new_plan, opts[:amount_paid])
      msg = "Please enter the amount of USD dollar amount of minutes to purchase."
    end

    return true if msg.blank?
    raise InvalidPlanTransition.new(old_plan, new_plan, opts, msg)
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
end
