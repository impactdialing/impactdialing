require 'librato_resque'
require 'impact_platform/heroku'

module CallFlow::DialQueue::Jobs
  class CacheVoters
    @queue = :dial_queue
    extend ImpactPlatform::Heroku::UploadDownloadHooks
    extend LibratoResque

    def self.perform(campaign_id, voter_ids, enabled)
      begin
        metrics    = ImpactPlatform::Metrics::JobStatus.started(self.to_s.underscore.gsub('/','_'))
        voters     = Voter.where(id: voter_ids).includes({
          campaign: :account,
          custom_voter_field_values: :custom_voter_field
        }, :voter_list, :household)
        campaign   = Campaign.find(campaign_id)
        dial_queue = CallFlow::DialQueue.new(campaign)

        if enabled.to_i > 0
          dial_queue.cache_all(voters)
        else
          dial_queue.remove_all(voters)
        end

        metrics.completed
      rescue Resque::TermException => e
        Resque.enqueue(self, campaign_id, voter_ids, enabled)
      end
    end
  end
end
