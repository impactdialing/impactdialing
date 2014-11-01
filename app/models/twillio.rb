class Twillio
  include SidekiqEvents

  def self.error_response_codes
    # 401: unauthorized
    # 405: method not allowed
    # 429: too many requests
    [400, 401, 404, 405, 429, 500]
  end

  def self.count_source(campaign, caller_session=nil)
    n = []
    n << campaign.type.to_s.downcase
    n << "ac-#{campaign.account_id}"
    n << "ca-#{campaign.id}"
    n << "cs-#{caller_session.id}" if caller_session.present?
    n.join('.')
  end

  def self.count_dial_success(campaign, caller_session=nil)
    ImpactPlatform::Metrics.count('dialer.dial.success', '1', count_source(campaign, caller_session))
  end

  def self.count_dial_error(campaign, caller_session=nil)
    ImpactPlatform::Metrics.count('dialer.dial.error', '1', count_source(campaign, caller_session))
  end

  def self.dial(voter, caller_session)
    campaign = caller_session.campaign
    call_attempt = setup_call(voter, caller_session, campaign)
    twilio_lib = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    http_response = twilio_lib.make_call(campaign, voter, call_attempt)
    response = JSON.parse(http_response)
    if error_response_codes.include?(response["status"])
      handle_failed_call(call_attempt, caller_session, voter, response)
    else
      handle_succeeded_call(call_attempt, caller_session, voter, response)
    end
  end

  def self.dial_predictive_em(iter, voter, dc)
    campaign = voter.campaign
    call_attempt = setup_call_predictive(voter, campaign, dc)
    twilio_lib = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    Rails.logger.info "#{call_attempt.id} - before call"
    http = twilio_lib.make_call_em(campaign, voter, call_attempt, dc)
    http.callback {
      Rails.logger.info "#{call_attempt.id} - after call"
      response = JSON.parse(http.response)
      if error_response_codes.include?(response["status"])
        handle_failed_call(call_attempt, nil, voter, response)
      else
        handle_succeeded_call(call_attempt, nil, voter, response)
      end
      iter.return(http)
       }
    http.errback { iter.return(http) }

  end

  def self.setup_call_predictive(voter, campaign, dc)
    attempt = voter.call_attempts.create(campaign:  campaign, dialer_mode:  campaign.type, status:  CallAttempt::Status::RINGING, call_start:  Time.now)
    voter.update_attributes(:last_call_attempt_id => attempt.id, :last_call_attempt_time => Time.now, status: CallAttempt::Status::RINGING)
    Call.create(call_attempt: attempt, state: "initial")
    attempt
  end



  def self.setup_call(voter, caller_session, campaign)
    attempt = voter.call_attempts.create(:campaign => campaign, :dialer_mode => campaign.type, :status => CallAttempt::Status::RINGING, :caller_session => caller_session, :caller => caller_session.caller, call_start:  Time.now)
    voter.update_attributes(:last_call_attempt_id => attempt.id, :last_call_attempt_time => Time.now, :caller_session_id => caller_session.id, status: CallAttempt::Status::RINGING)
    caller_session.update_attributes(on_call: true, available_for_call: false, attempt_in_progress: attempt, voter_in_progress: voter)
    Call.create(call_attempt: attempt, state: "initial")
    attempt
  end

  def self.handle_succeeded_call(call_attempt, caller_session, voter, response)
    count_dial_success(voter.campaign, caller_session)
    call_attempt.update_attributes(:sid => response["sid"])
  end

  def self.handle_failed_call(attempt, caller_session, voter, response)
    TwilioLogger.error(response['TwilioResponse'] || response)
    count_dial_error(voter.campaign, caller_session)
    attempt.update_attributes(status: CallAttempt::Status::FAILED, wrapup_time: Time.now)
    voter.update_attributes(status: CallAttempt::Status::FAILED)
    unless caller_session.nil?
      caller_session.update_attributes(attempt_in_progress: nil, voter_in_progress: nil, on_call: true, available_for_call: true)
      Providers::Phone::Call.redirect_for(caller_session)
    end
  end
end