class Twillio
  include SidekiqEvents

  def self.dial(voter, caller_session)
    campaign = caller_session.campaign
    call_attempt = setup_call(voter, caller_session, campaign)
    twilio_lib = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    http_response = twilio_lib.make_call(campaign, voter, call_attempt)
    response = JSON.parse(http_response)
    if response["status"] == 400
      handle_failed_call(call_attempt, caller_session, voter)
    else
      call_attempt.update_attributes(:sid => response["sid"])
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
      if response["status"] == 400
        handle_failed_call(call_attempt, nil, voter)
      else
        call_attempt.update_attributes(:sid => response["sid"])
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

  def self.handle_failed_call(attempt, caller_session, voter)
    attempt.update_attributes(status: CallAttempt::Status::FAILED, wrapup_time: Time.now)
    voter.update_attributes(status: CallAttempt::Status::FAILED)
    unless caller_session.nil?
      caller_session.update_attributes(attempt_in_progress: nil, voter_in_progress: nil, on_call: true, available_for_call: true)
      caller_session.redirect_caller
    end
  end



end