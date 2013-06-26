require 'rspec/rails'
module TwilioHelper

  def mock_redirect_account_has_no_funds(caller, caller_session)
    Twilio.should_receive(:connect).with(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Call.should_receive(:redirect).with(caller_session.session_key, "http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{caller.id}/account_out_of_funds?session_id=#{caller_session.id}")
  end

  def mock_redirect_campaign_time_period_exceeded(caller, caller_session)
    Twilio.should_receive(:connect).with(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Call.should_receive(:redirect).with(caller_session.session_key, "http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{caller.id}/time_period_exceeded?session_id=#{caller_session.id}")
  end

  def mock_make_call_as_failed
    twilio_lib = mock
    TwilioLib.should_receive(:new).with(TWILIO_ACCOUNT, TWILIO_AUTH).and_return(twilio_lib)
    twilio_lib.should_receive(:make_call).and_return("{\"status\": 400}")

  end

  def mock_make_call_as_failed_em
    Twillio.should_receive(:dial_em)
    CallAttempt.first.update_attributes(status: "Call failed")
  end

  def mock_make_call_as_success
    twilio_lib = mock
    TwilioLib.should_receive(:new).with(TWILIO_ACCOUNT, TWILIO_AUTH).and_return(twilio_lib)
    twilio_lib.should_receive(:make_call).and_return("{\"sid\": \"12345\"}")
  end

  def mock_redirect_caller_phones_only(caller, caller_session)
    Twilio.should_receive(:connect).with(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Call.should_receive(:redirect).with(caller_session.session_key, "http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{caller.id}/ready_to_call?session_id=#{caller_session.id}")
  end

  def create_dummy_call(voter, campaign)
    attempt = voter.call_attempts.create(campaign:  campaign, dialer_mode:  campaign.type, status:  CallAttempt::Status::RINGING, call_start:  Time.now)
    voter.update_attributes(:last_call_attempt_id => attempt.id, :last_call_attempt_time => Time.now, status: CallAttempt::Status::RINGING)
    Call.create(call_attempt: attempt, state: "initial")
  end

end