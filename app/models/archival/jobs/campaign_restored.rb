module Archival::Jobs
  class CampaignRestored
    extend LibratoResque
    @queue = :background_worker

    def self.add_to_queue(campaign_id)
      Resque.enqueue(self, campaign_id)
    end

    def self.perform(campaign_id)
      campaign   = ::Campaign.find campaign_id
      dial_queue = campaign.dial_queue
      
      campaign.all_voters.with_enabled(:list).includes({
          campaign: :account,
          custom_voter_field_values: :custom_voter_field
        }, :voter_list, :household
      ).find_in_batches(batch_size: 500) do |voters|
        dial_queue.cache_all(voters)
      end
    end
  end
end
