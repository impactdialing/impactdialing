class Twiml::CallerSessionsController < TwimlController
  def dialing_prohibited
    caller_session = CallerSession.find params[:caller_session_id]
    caller_session.end_caller_session
    
    render xml: caller_session.abort_dial_twiml
  end
end
