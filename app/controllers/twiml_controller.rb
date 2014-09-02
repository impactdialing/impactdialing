class TwimlController < ApplicationController  
private
  def render_abort_twiml_unless_fit_to(point_in_call_flow, caller_session, &block)
    unless block_given?
      raise ArgumentError, "A block is required because that is all that will run when rendering abort twiml."
    end

    if caller_session.fit_to_dial?
      yield
    else
      caller_session.end_caller_session
      render xml: caller_session.send("abort_#{point_in_call_flow}_twiml")
    end
  end
end