class TwilioController < ApplicationController
  include ::Twilio
  before_filter :retrieve_call_details

  def callback
    logger.info "[dialer] call picked up. #{@log_message}; Call Status : #{params['CallStatus']}"
    if params['CallStatus'] == 'in-progress'
      response = @call_attempt.campaign.script.robo_recordings.first.twilio_xml(@call_attempt)
      render :xml => response
    else
      render :xml => Twilio::Verb.hangup
    end
  end

  def report_error
    logger.info "[dialer] error. #{@log_message}"
    render :text => ''
  end

  def call_ended
    logger.info "[dialer] call ended. #{@log_message}"
    render :text => ''
  end

  private
  def retrieve_call_details
    @call_attempt = CallAttempt.find(params[:call_attempt_id])
    @call_attempt.update_attribute('status', CallAttempt::Status::MAP[params['CallStatus']])
    campaign = @call_attempt.campaign
    voter = @call_attempt.voter
    @log_message = "call_attempt: #{@call_attempt.id} campaign: #{campaign.name}, phone: #{voter.Phone}\n callback parameters: #{params.inspect}"
  end
end
