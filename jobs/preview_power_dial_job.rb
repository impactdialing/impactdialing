class PreviewPowerDialJob
  include Sidekiq::Worker
  sidekiq_options :retry => false
  sidekiq_options :failures => true

  def perform(caller_session_id, voter_id)
    caller_session = CallerSession.find_by_id_cached(caller_session_id)
    if caller_session.funds_not_available?
      Providers::Phone::Call.redirect_for(caller_session, :account_has_no_funds)
      return
    end

    if caller_session.time_period_exceeded?
      Providers::Phone::Call.redirect_for(caller_session, :time_period_exceeded)
      return
    end

    voter = Voter.find(voter_id)
    begin
      Twillio.dial(voter, caller_session)
    rescue ActiveRecord::StaleObjectError
      Providers::Phone::Call.redirect_for(caller_session)
    end
  end
end