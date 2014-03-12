##
# Use an instance of this class to act on user requests
# to change their plan. It currently supports these plans:
#
# - trial (pseudo-plan)
# - basic
# - business
# - pro
# - per_minute
#
# Transitioning from per_minute to basic, business or pro is not allowed.
# Transitioning to Trial from anything is not allowed.
# Otherwise, this class handles all upgrades, downgrades and buying of minutes.
#
# Example Usage:
#
#     manager = Billing::SubscriptionManager.new(provider_customer_id, record)
#     manager.update!('business', {callers_allowed: 5})
#     # assuming subscription.plan is 'trial', this will upgrade it to business and
#     # purchase 5 seats
#     # or
#     manager.update!('per_minute', {amount_paid: 75.0})
#     # assuming subscription.plan is 'trial' or 'per_minute', this will purchase minutes
#     # and eventually trigger an update to the account quota when the `charge.succeeded`
#     # event is processed.
#
class Billing::SubscriptionManager
  attr_reader :customer_id, :record, :payment_gateway, :plans, :quota

# private
  ##
  # Returns true if the given new_plan is an upgrade from old_plan
  # or an increase in callers_allowed quota has been requested.
  # Downgrades and decreases in plan quotas are not prorated.
  #
  def prorate?(new_plan, callers_allowed=0)
    old_plan = record.plan
    return false if plans.is_trial?(old_plan)
    plans.recurring?(new_plan) &&
    ( plans.is_upgrade?(old_plan, new_plan) ||
     quota.callers_allowed < callers_allowed )

    return plans.is_upgrade?(old_plan, new_plan) || old_plan == new_plan
  end

  def upgrade_or_downgrade!(plan, callers_allowed)
    subscription = payment_gateway.update_subscription(plan, callers_allowed, prorate?(plan))
    if prorate?(plan)
      payment_gateway.create_and_pay_invoice
    end
    return subscription
  end

  def buy_minutes!(amount_paid)
    return payment_gateway.create_charge(amount_paid)
  end

public

  def initialize(customer_id, record, quota)
    @customer_id     = customer_id
    @record          = record
    @quota           = quota
    @payment_gateway = Billing::PaymentGateway.new(customer_id)
    @plans           = Billing::Plans.new
  end

  def update!(new_plan, opts={})
    old_plan = record.plan
    plans.validate_transition!(old_plan, new_plan, opts)

    # plans are either recurring or buying minutes.
    if plans.recurring?(new_plan)
      return upgrade_or_downgrade!(new_plan, opts[:callers_allowed])
    else
      return buy_minutes!(opts[:amount_paid])
    end
  end
end
