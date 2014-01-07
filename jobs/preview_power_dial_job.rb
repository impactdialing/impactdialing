class PreviewPowerDialJob
  include Sidekiq::Worker
  sidekiq_options :retry => false
  sidekiq_options :failures => true

  def perform(caller_session_id, voter_id)
    caller_session = CallerSession.find_by_id_cached(caller_session_id)
    if caller_session.funds_not_available?
      msg = "Pong: Account[#{caller_session.campaign.account.id}] Campaign[#{caller_session.campaign.id}] PreviewPowerDialJob => redirecting - funds not available"
      p msg
      Rails.logger.debug msg
      Providers::Phone::Call.redirect_for(caller_session, :account_has_no_funds)
      return
    end

    if caller_session.time_period_exceeded?
      msg = "Pong: Account[#{caller_session.campaign.account.id}] Campaign[#{caller_session.campaign.id}] PreviewPowerDialJob => redirecting - time period exceeded"
      p msg
      Rails.logger.debug msg
      Providers::Phone::Call.redirect_for(caller_session, :time_period_exceeded)
      return
    end

    voter = Voter.find(voter_id)
    begin
      msg = "Pong: Account[#{caller_session.campaign.account.id}] Campaign[#{caller_session.campaign.id}] PreviewPowerDialJob => dialing #{voter.phone}"
      p msg
      Rails.logger.debug msg
      Twillio.dial(voter, caller_session)
      msg = "Pong: Account[#{caller_session.campaign.account.id}] Campaign[#{caller_session.campaign.id}] PreviewPowerDialJob => dialed #{voter.phone}"
      p msg
      Rails.logger.debug msg
    rescue ActiveRecord::StaleObjectError => e
      msg = "Pong: Account[#{caller_session.campaign.account.id}] Campaign[#{caller_session.campaign.id}] PreviewPowerDialJob => redirecting - rescued from ActiveRecord::StaleObjectError: #{e.message}"
      p msg
      Rails.logger.debug msg
      Providers::Phone::Call.redirect_for(caller_session)
    end
  end
end