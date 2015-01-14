require 'impact_platform'

module CallFlow::Jobs
  class Recycle
    @queue = :upload_download
    extend ImpactPlatform::Heroku::UploadDownloadHooks
    extend LibratoResque

    def self.perform
      CallerSession.on_call.select('DISTINCT caller_sessions.campaign_id').includes(:campaign).find_in_batches do |caller_sessions|
        caller_sessions.each do |caller_session|
          campaign   = caller_session.campaign
          dial_queue = CallFlow::DialQueue.new(campaign)
          stale      = dial_queue.available.presented_and_stale

          stale.each do |scored_phone|
            score     = scored_phone.last
            phone     = scored_phone.first
            household = campaign.households.find_by_phone(phone)
            
            household.update_attributes({
              presented_at: score
            })
            dial_queue.dialed(household)
          end

          dial_queue.recycle!
        end
      end
    end
  end
end
