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

private
  def stripe_livemode?
    # Rails normalizes this to True or False class.
    params[:livemode]
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

public
  def stripe
    if process_stripe_event?
      # Register this event id to avoid processing it again.
      ::Billing::StripeEvent.create!({provider_id: params[:id]})
      # Queue job to pull and process event matching this id.
      Resque.enqueue(Billing::Jobs::StripeEvent, params[:id])
    end

    # Raise an exception to return a response other than 200.
    # Stripe will retry once an hour up to 3 days.
    head :ok and return
  end
end
