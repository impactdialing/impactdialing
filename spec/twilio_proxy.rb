require 'rspec/rails'
class TwilioProxy

  def initialize
    @conn = Faraday.new(:url => 'http://localhost:3000')
  end

  def callin(resp=false)
    response = @conn.post '/callin/create'
    resp ? response : @conn
  end

  def identify(digits, resp=false)
    response = callin.post '/callin/identify?attempt=1', { Digits: digits }
    resp ? response : @conn
  end

  def read_instruction_options(caller, digits, resp=false)
    response = identify(caller.pin).post "caller/#{caller.id}/read_instruction_options?session_id=#{caller.caller_sessions.first.id}", { Digits:  digits}
    resp ? response : @conn
  end

  def ready_to_call(caller, resp=false)
    response = read_instruction_options(caller, "*").post "caller/#{caller.id}/ready_to_call?session_id=#{caller.caller_sessions.first.id}"
    resp ? response : @conn
  end

  def conference_started_phones_only_preview(caller, voter, digits, resp=false)
    response = ready_to_call(caller).post "caller/#{caller.id}/conference_started_phones_only_preview?session_id=#{caller.caller_sessions.first.id}&amp;voter=#{voter.id}", {Digits: digits}
    resp ? response : @conn
  end

  def conference_started_phones_only_power(caller, voter, resp=false)
    response = ready_to_call(caller).post "caller/#{caller.id}/conference_started_phones_only_power?session_id=#{caller.caller_sessions.first.id}&amp;voter=#{voter.id}"
    resp ? response : @conn
  end


  def redirect_account_out_of_funds(caller)
    @conn.post "/caller/#{caller.id}/account_out_of_funds"
  end

  def redirect_time_period_exceeded(caller)
    @conn.post "/caller/#{caller.id}/time_period_exceeded"
  end

  def incoming_call(call, answered_by, call_status, campaign_type, resp=false)
    response = @conn.post "/calls/#{call.id}/incoming?campaign_type=#{campaign_type}", { answered_by:  answered_by, call_status: call_status}
    resp ? response : @conn
  end

  def disconect_call(call, campaign_type, resp=false)
    response = incoming_call(call, "human", "in-progress", campaign_type).post "/calls/#{call.id}/disconnected"
    resp ? response : @conn
  end

  def call_ended(call, answered_by, call_status, campaign_type, resp=false)
    response = @conn.post "/calls/#{call.id}/call_ended?campaign_type=#{campaign_type}", { answered_by:  answered_by, call_status: call_status}
    resp ? response : @conn
  end

  def gather_response(caller, question_number, resp=false)
    response = @conn.post "/caller/#{caller.id}/gather_response", {session_id: caller.caller_sessions.first.id,
        question_number: 0}
    resp ? response : @conn
  end

  def submit_response(caller, question, digits, resp=false)
    response = @conn.post "/caller/#{caller.id}/submit_response?question_id=#{question.id}&question_number=0&session_id=#{caller.caller_sessions.first.id}", {Digits: digits}
    resp ? response : @conn
  end

  def next_question(caller, question_number, resp=false)
    response = @conn.post "/caller/#{caller.id}/next_question?question_number=#{question_number}&session_id=#{caller.caller_sessions.first.id}"
    resp ? response : @conn
  end

  def next_call(caller, resp=false)
    response = @conn.post "caller/#{caller.id}/next_call?session_id=#{caller.caller_sessions.first.id}"
    resp ? response : @conn
  end





end
