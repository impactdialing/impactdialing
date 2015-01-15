require 'impact_platform/heroku'

module CallFlow::Jobs
  class CacheVoters
    @queue = :upload_download
    extend ImpactPlatform::Heroku::UploadDownloadHooks
    extend LibratoResque

    def self.perform(campaign_id, voter_ids, enabled)
      metrics    = ImpactPlatform::Metrics::JobStatus.started(self.to_s.underscore.gsub('/','_'))
      voters     = Voter.where(id: voter_ids).includes({campaign: :account}, :voter_list, :household)
      campaign   = Campaign.find(campaign_id)
      dial_queue = CallFlow::DialQueue.new(campaign)

      if enabled.to_i > 0
        dial_queue.cache_all(voters)
      else
        dial_queue.remove_all(voters)
      end

      metrics.completed
    end
  end
end
