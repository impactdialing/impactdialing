##
# Pull and cache all Stripe events registered via webhook and process relevant items.
#
# See list of all events here: https://stripe.com/docs/api#event_types
#
class Billing::Jobs::StripeEvent
  @queue = :background_worker

  def self.perform(stripe_event_id)
    stripe_event  = ::Billing::StripeEvent.pending.where(provider_id: stripe_event_id).first

    return if stripe_event.nil?

    processed     = false

    if stripe_event.bare?
      rstripe_event = ::Billing::PaymentGateway.new(nil, stripe_event_id).event
      stripe_event.cache_event!(rstripe_event)
    end

    Rails.logger.debug "Jobs::StripeEvent: processing - #{stripe_event.name} - #{stripe_event.provider_id}"

    case stripe_event.name
    when 'customer.subscription.created'
      # update sub deets
      processed = true
    when 'customer.subscription.deleted'
      # update sub status
      processed = true
    when 'customer.subscription.updated'
      # update sub deets
      processed = true
    when 'customer.card.created'
      customer_id     = stripe_event.data[:object][:customer]
      payment_gateway = ::Billing::PaymentGateway.new(customer_id)
      account         = Account.find_by_billing_provider_customer_id(customer_id)
      card            = payment_gateway.card
      processed       = create_or_update_credit_card(account, card)
    when 'customer.card.updated'
      customer_id     = stripe_event.data[:object][:customer]
      payment_gateway = ::Billing::PaymentGateway.new(customer_id)
      card            = payment_gateway.card
      account         = Account.find_by_billing_provider_customer_id(customer_id)
      processed       = create_or_update_credit_card(account, card)
    when 'customer.card.deleted'
      # Stripe sends this after a customer updates their card
      # info.
      customer_id     = stripe_event.data[:object][:customer]
      payment_gateway = ::Billing::PaymentGateway.new(customer_id)
      account         = Account.find_by_billing_provider_customer_id(customer_id)
      credit_card     = account.billing_credit_card
      if credit_card.present? && credit_card.provider_id == stripe_event.data[:object][:id]
        Rails.logger.debug "Jobs::StripeEvent: destroying: #{credit_card.provider_id} == #{stripe_event.data[:object][:id]}"
        credit_card.destroy
        processed = credit_card.destroyed?
      else
        Rails.logger.debug "Jobs::StripeEvent: skipping: #{credit_card.provider_id} != #{stripe_event.data[:object][:id]}"
        processed = true
      end
    when 'charge.succeeded'
      # update quota for per minute
      processed = true
    when 'charge.failed'
      # notify someone and possibly retry in X hours
      processed = true
    else
      # quietly ignore events we don't handle currently
      processed = true
      # queue for removal in e.g. 24 hours?
    end

    if !processed
      if stripe_event.age < 24.hours
        Rails.logger.debug "Jobs::StripeEvent: requeueing"
        Resque.enqueue(Billing::Jobs::StripeEvent, stripe_event_id)
        return
      end
      # This event will no longer be retried.
      Rails.logger.error "Jobs::StripeEvent: Abandoning #{stripe_event_id}. This job has been in the queue for 24 hours."
      processed = true
    end

    if processed
      stripe_event.processed = Time.now
      stripe_event.save!
    end
  end

  def self.create_or_update_credit_card(account, card)
    processed = false
    if account.present? && card.present?
      if account.billing_credit_card.present?
        processed = account.billing_credit_card.update_attributes({
          provider_id: card.id,
          exp_month: card.exp_month,
          exp_year: card.exp_year,
          last4: card.last4
        })
        Rails.logger.debug "Jobs::StripeEvent: updating #{credit_card.id} #{credit_card.errors.full_messages.join('; ')}"
      else
        credit_card = account.create_billing_credit_card({
          provider_id: card.id,
          exp_month: card.exp_month,
          exp_year: card.exp_year,
          last4: card.last4
        })
        Rails.logger.debug "Jobs::StripeEvent: created #{credit_card.id} #{credit_card.errors.full_messages.join('; ')}"
        processed = credit_card.errors.empty?
      end
    end
    return processed
  end
end
