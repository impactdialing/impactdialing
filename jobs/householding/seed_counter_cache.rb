require 'librato_resque'

module Householding
  class SeedCounterCache
    include Resque::Plugins::UniqueJob
    extend LibratoResque
    @queue = :data_migrations

    def self.perform(type, campaign_id, lower_household_id=nil, upper_household_id=nil)
      if type == 'campaign'
        Campaign.reset_counters(campaign_id, :households)
      else
        campaign = Campaign.find campaign_id
        campaign.households.where(id: (lower_household_id..upper_household_id)) do |household|
          Household.reset_counters(household.id, :voters)
        end
      end
    end
  end
end