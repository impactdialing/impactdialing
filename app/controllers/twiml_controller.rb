class TwimlController < ApplicationController  
  layout false

  before_filter :count_fallback_url_hit

private
  def render_abort_twiml_unless_fit_to(point_in_call_flow, caller_session, &block)
    unless block_given?
      raise ArgumentError, "A block is required because that is all that will run when rendering abort twiml."
    end

    if caller_session.fit_to_dial? and process_request?
      yield
    else
      caller_session.end_caller_session
      xml = caller_session.send("abort_#{point_in_call_flow}_twiml")
      render({xml: xml}) and return
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

  ##
  # ENV config accessor. Used to toggle processing of fallback urls
  # regardless of error code.
  def process_fallback_urls
    ENV['TWILIO_PROCESS_FALLBACK_URLS'].to_i
  end

  ##
  # Twilio error codes that can safely be retried.
  #
  # Currently limited to errors that indicate Twilio's
  # request never reached our servers. These are the
  # most common failures and can always be safely retried.
  #
  # See: https://www.twilio.com/docs/errors/reference
  #
  # Updated: Oct 14 2015
  def retry_error_codes
    [
      11200, # HTTP retrieval failure
      11205, # HTTP connection failure
      11210, # HTTP bad host name
      12400  # Internal failure (internal to Twilio)
    ]
  end

  def process_fallback_urls?
    process_fallback_urls > 0 and
    retry_error_codes.include?(params[:ErrorCode].to_i)
  end

  def fallback_url_requested?
    params[:ErrorCode] and params[:ErrorUrl]
  end

  def process_request?
    (not fallback_url_requested?) or process_fallback_urls?
  end

  def abort_request?
    not process_request?
  end

  def abort_caller_if_unprocessable_fallback_url
    abort_for 'caller_sessions'
  end

  def abort_lead_if_unprocessable_fallback_url
    abort_for 'lead'
  end

  def abort_for(namespace)
    if abort_request?
      render_twiml namespace, 'unprocessable_fallback_url' and return
    end
    true
  end

  def render_twiml(namespace, template)
    render "twiml/#{namespace}/#{template}"
  end
end

