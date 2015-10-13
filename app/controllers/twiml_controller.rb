class TwimlController < ApplicationController  
  layout false

  before_filter :count_fallback_url_hit

private
  def render_abort_twiml_unless_fit_to(point_in_call_flow, caller_session, &block)
    unless block_given?
      raise ArgumentError, "A block is required because that is all that will run when rendering abort twiml."
    end

    if caller_session.fit_to_dial?
      yield
    else
      caller_session.end_caller_session
      render xml: caller_session.send("abort_#{point_in_call_flow}_twiml") and return
    end
  end

  def count_fallback_url_hit
    return true unless fallback_url_requested?

    source = []
    if params[:campaign_id]
      campaign = Campaign.find params[:campaign_id]
      source << "ac-#{campaign.account_id}"
      source << "ca-#{campaign.id}"
    end
    if params[:CallSid]
      source << "sid-#{params[:CallSid]}"
    end
    source << "code-#{params[:ErrorCode]}"
    source << "url-#{params[:ErrorUrl]}"
    metric_name = "twiml.fallback_url_hit"
    ImpactPlatform::Metrics.count(metric_name, 1, source.join('.'))
  end

  def process_fallback_urls?
    ENV['TWILIO_FULFILL_FALLBACK_URLS'].to_i > 0
  end

  def fallback_url_requested?
    params[:ErrorCode] and params[:ErrorUrl]
  end

  def process_request?
    (not fallback_url_requested?) or
    (fallback_url_requested? and process_fallback_urls?)
  end
end

