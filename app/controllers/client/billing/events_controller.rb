##
#
# Important Note from Stripe (https://stripe.com/docs/webhooks):
#
#     With application webhooks, it's important to note that while
#     only test webhooks will be sent to development applications,
#     both live and test webhooks will be sent to production applications.
#     We recommend that you check the livemode of the webhook before processing events.
#

class Client::Billing::EventsController < ApplicationController
  skip_before_filter :verify_authenticity_token

  if instrument_actions?
    instrument_action :stripe
  end

private
  def stripe_livemode?
    # Rails normalizes this to True or False class.
    if params[:livemode].kind_of?(TrueClass) or params[:livemode].kind_of?(FalseClass)
      return params[:livemode]
    else
      return params[:livemode] == '1' 
    end
  end

  def stripe_production?
    Rails.env.heroku? && stripe_livemode?
  end

  def stripe_development?
    (Rails.env.development? || Rails.env.heroku_staging?) && !stripe_livemode?
  end

  def process_stripe_event?
    stripe_production? || stripe_development?
  end

  def stripe_event_id
    params.require(:id)
  end

public
  def stripe
    if process_stripe_event?
      # Register this event id to avoid processing it again.
      ::Billing::StripeEvent.create!({provider_id: stripe_event_id})
      # Queue job to pull and process event matching this id.
      Resque.enqueue(Billing::Jobs::StripeEvent, stripe_event_id)
    end

    # Raise an exception to return a response other than 200.
    # Stripe will retry once an hour up to 3 days.
    head :ok and return
  end
end
