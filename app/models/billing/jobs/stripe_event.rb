##
# Pull and cache all Stripe events registered via webhook and process relevant items.
#
# See list of all events here: https://stripe.com/docs/api#event_types
#
# Current objective of this class is to allow the app to take the appropriate action
# when an automated payment is received, i.e. update quotas.
#
# Automated payment scenarios:
# - autorecharge (per minute plans only)
# - subscription renewal (basic, pro and business plans only)
#
# Subscription Renewal Event Scenario: https://support.stripe.com/questions/what-events-can-i-see-when-a-subscription-is-renewed
#
# Autorecharge Event Scenario: most easily handled via `charge.succeeded` event.
# This will depend on the metadata attr of the `Stripe::Charge` object.
# When this job processes a `charge.succeeded` event it will look for a key
# called `autorecharge` in the metadata attr and expect the value to be boolean 0 or 1.
# When the value of `autorecharge` is 1 then this job will call +Quota#plan_changed!+.
# Otherwise the `charge.succeeded` event will be ignored.
#
# Last updated: Mar 16 2014
#
class Billing::Jobs::StripeEvent
  @queue = :background_worker

  def self.perform(stripe_event_id)
    stripe_event  = ::Billing::StripeEvent.pending.where(provider_id: stripe_event_id).first

    return if stripe_event.nil?

    if stripe_event.bare?
      rstripe_event = ::Billing::PaymentGateway.new(nil, stripe_event_id).event
      stripe_event.cache_event!(rstripe_event)
    end

    Rails.logger.debug "Jobs::StripeEvent: processing - #{stripe_event.name} - #{stripe_event.provider_id}"

    case stripe_event.name
    when 'customer.card.created'
      finish_job(stripe_event) do
        create_or_update_credit_card!(stripe_event)
      end
    when 'customer.card.updated'
      finish_job(stripe_event) do
        create_or_update_credit_card!(stripe_event)
      end
    when 'customer.card.deleted'
      # Stripe sends this after a customer updates their card
      # info, presumably they are deleting the old card and creating
      # a new one; make sure we don't delete the new one!
      finish_job(stripe_event) do
        destroy_credit_card(stripe_event)
      end
    when 'charge.succeeded'
      # only handle per minute subscriptions for now
      finish_job(stripe_event) do
        update_quota!(stripe_event)
      end
    when 'charge.failed'
      # notify customer
    #when 'customer.subscription.updated'
    when 'invoice.payment_succeeded'
      finish_job(stripe_event) do
        update_quota_and_subscription!(stripe_event)
      end
    when 'invoice.payment_failed'
      # only handle recurring subscriptions for now
      # hmm, should we notify and give customers a day or two to reconcile?
    else
      # quietly ignore events we don't handle currently
      # queue for removal in e.g. 24 hours?
      finish_job(stripe_event)
    end
  end

  def self.finish_job(stripe_event, &block)
    ActiveRecord::Base.transaction do
      yield if block_given?
      event_processed!(stripe_event)
    end
  end

  def self.event_processed!(stripe_event)
    stripe_event.processed = Time.now
    stripe_event.save!
  end

  # def self.event_not_processed(stripe_event)
  #   if stripe_event.age < 24.hours
  #     Rails.logger.debug "Jobs::StripeEvent: requeueing"
  #     Resque.enqueue(Billing::Jobs::StripeEvent, stripe_event.provider_id)
  #   end
  #   # This event will no longer be retried.
  #   Rails.logger.error "Jobs::StripeEvent: Abandoning #{stripe_event_id}. This job has been in the queue for 24 hours."
  #   event_processed!
  # end

  def self.create_or_update_credit_card!(stripe_event)
    customer_id     = stripe_event.data[:object][:customer]
    payment_gateway = ::Billing::PaymentGateway.new(customer_id)
    card            = payment_gateway.card
    account         = Account.find_by_billing_provider_customer_id(customer_id)
    processed       = false
    if account.present? && card.present?
      if account.billing_credit_card.present?
        credit_card             = account.billing_credit_card
        credit_card.provider_id = card.id
        credit_card.exp_month   = card.exp_month
        credit_card.exp_year    = card.exp_year
        credit_card.last4       = card.last4
        Rails.logger.debug "Jobs::StripeEvent: updating #{credit_card.id} #{credit_card.errors.full_messages.join('; ')}"
      else
        credit_card = account.build_billing_credit_card({
          provider_id: card.id,
          exp_month: card.exp_month,
          exp_year: card.exp_year,
          last4: card.last4
        })
        Rails.logger.debug "Jobs::StripeEvent: created #{credit_card.id} #{credit_card.errors.full_messages.join('; ')}"
      end

      credit_card.save!
    end
  end

  def self.destroy_credit_card(stripe_event)
    customer_id     = stripe_event.data[:object][:customer]
    account         = Account.find_by_billing_provider_customer_id(customer_id)
    credit_card     = account.billing_credit_card
    if credit_card.present? && credit_card.provider_id == stripe_event.data[:object][:id]
      Rails.logger.debug "Jobs::StripeEvent: destroying: #{credit_card.provider_id} == #{stripe_event.data[:object][:id]}"
      credit_card.destroy
    end
  end

  def self.update_quota!(stripe_event, autorenewal=false)
    customer_id     = stripe_event.data[:object][:customer]
    stripe_obj_type = stripe_event.data[:object][:object]
    account         = Account.find_by_billing_provider_customer_id(customer_id)
    quota           = account.quota
    plan_id         = account.billing_subscription.plan
    plan            = plans.find(plan_id)

    if stripe_obj_type == 'charge'
      amount       = stripe_event.data[:object][:amount]
      autorecharge = stripe_event.data[:object][:metadata][:autorecharge]
      update_per_minute_quota!(quota, plan, amount, autorecharge)
    elsif stripe_obj_type == 'invoice'
      update_recurring_quota!(quota, plan, autorenewal)
    end
  end

  def self.update_per_minute_quota!(quota, plan, amount, autorecharge)
    # quietly ignore manual recharges
    return true unless autorecharge

    quota.add_minutes(plan, amount)
    quota.save!
  end

  def self.update_recurring_quota!(quota, plan, autorenewal)
    # quietly ignore manual recharges
    return true unless autorenewal

    quota.reset(plan)
    quota.save!
  end

  def self.update_subscription!(stripe_event)
    customer_id  = stripe_event.data[:object][:customer]
    status       = stripe_event.data[:object][:status]
    account      = Account.find_by_billing_provider_customer_id(customer_id)
    subscription = account.billing_subscription
    plan_id      = subscription.plan
    plan         = plans.find(plan_id)

    subscription.provider_status = status
    subscription.save!
  end

  def self.update_quota_and_subscription!(stripe_event)
    customer_id = stripe_event.data[:object][:customer]
    account     = Account.find_by_billing_provider_customer_id(customer_id)
    invoice     = stripe_event.data[:object]
    type        = invoice[:lines][:data][0][:type] # subscription or invoice

    return unless type == 'subscription'

    stripe_subscription = invoice[:lines][:data][0]
    start_period        = stripe_subscription[:period][:start]
    end_period          = stripe_subscription[:period][:end]
    subscription        = account.billing_subscription
    autorenewal         = subscription.is_renewal?(start_period, end_period)

    return unless autorenewal

    subscription.renewed!(start_period, end_period)
    update_quota!(stripe_event, autorenewal)
  end

  def self.plans
    @plans ||= Billing::Plans.new
  end
end
