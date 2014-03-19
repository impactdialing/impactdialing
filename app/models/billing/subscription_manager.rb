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
    old_plan        = record.plan
    return false if plans.is_trial?(old_plan)
    return false if plans.buying_minutes?(old_plan)
    return false if plans.buying_minutes?(new_plan)
    return plans.is_upgrade?(old_plan, new_plan) ||
           callers_allowed.to_i > quota.callers_allowed
  end

  def update_recurring_subscription!(new_plan, callers_allowed)
    return nil unless plans.recurring?(new_plan)

    prorate      = prorate?(new_plan)
    subscription = payment_gateway.update_subscription(new_plan, callers_allowed, prorate)
    if prorate
      payment_gateway.create_and_pay_invoice
    end
    return subscription
  end

  def cancel_recurring_subscription!
    payment_gateway.cancel_subscription
  end

  def buy_minutes!(amount_paid)
    cancel_recurring_subscription!
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

  def update!(new_plan, opts={}, &block)
    old_plan          = record.plan
    minutes_available = quota.minutes_available?

    plans.validate_transition!(old_plan, new_plan, minutes_available, opts)

    # plans are either recurring or buying minutes.
    provider_object = update_recurring_subscription!(new_plan, opts[:callers_allowed])
    provider_object ||= buy_minutes!(opts[:amount_paid])

    if provider_object.present?
      opts.merge!({
        prorate: prorate?(new_plan, opts[:callers_allowed]),
        old_plan_id: old_plan
      })

      if block_given?
        ActiveRecord::Base.transaction do
          yield(provider_object, opts)
        end
      end
    end
  end
end
