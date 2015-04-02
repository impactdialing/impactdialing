require 'librato_resque'

module CallFlow::Jobs
  class PruneHouseholds
    include Resque::Plugins::UniqueJob
    extend LibratoResque
    @queue = :data_migrations

    def self.perform(campaign_id, *household_ids)
      begin
        campaign   = Campaign.find campaign_id
        campaign.households.includes(:voters, :call_attempts).where(id: household_ids).each do |household|
          if household.voters.count.zero?
            if campaign.dial_queue.exists?
              # remove it from the cache
              campaign.dial_queue.remove_household(household.phone)
            end

            if household.call_attempts.count.zero?
              # remove it from the rdb
              household.destroy
            end
          end
        end
      rescue Resque::TermException => e
        Resque.enqueue(self, campaign_id, *household_ids)
      end
    end
  end
end
