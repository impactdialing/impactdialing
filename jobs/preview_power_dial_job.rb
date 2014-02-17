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

    campaign = voter.campaign

    Rails.logger.error "RecycleRate PreviewPowerDialJob CallerSession[#{caller_session_id}] Voter[#{voter_id}] #{campaign.try(:type) || 'Campaign'}[#{campaign.try(:id)}]"

    if campaign.present? && campaign.within_recycle_rate?(voter)
      msg = "PreviewPowerDialJob - RecycleRateError:" +
            " CallerSession[#{caller_session.id}]" +
            " Voter[#{voter.id}] Campaign[#{campaign.id}]"
      Rails.logger.error msg
    end

    begin
      Twillio.dial(voter, caller_session)
      # if campaign.within_recycle_rate?(voter)
      #   # Twillio.dial(voter, caller_session)
      # else
      #   # tell the caller what happened
      #   # redirect the caller to trigger an update to the lead info
      #   # Providers::Phone::Call.redirect_for(caller_session, :voter_banned_by_recycle_rate)
      # end
    rescue ActiveRecord::StaleObjectError => e
      Providers::Phone::Call.redirect_for(caller_session)
      # rescue from any exception > tell the caller what happened > redirect
    end
  end
end
