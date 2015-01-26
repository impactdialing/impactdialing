require 'librato_resque'

module Householding
  class SeedDialQueue
    include Resque::Plugins::UniqueJob
    extend LibratoResque
    @queue = :data_migrations

    def self.perform(campaign_id, voter_list_id, lower_voter_id, upper_voter_id)
      voter_list = VoterList.includes(:campaign).where(campaign_id: campaign_id, id: voter_list_id).first
      campaign   = voter_list.campaign
      if voter_list.enabled?
        p "Seeding DialQueue Campaign[#{campaign_id}] EnabledList[#{voter_list_id}] Voter[#{lower_voter_id}..#{upper_voter_id}]"
        voters = voter_list.voters.where(id: (lower_voter_id..upper_voter_id)).includes({campaign: :account, custom_voter_field_values: :custom_voter_field}, :voter_list, :household)
        p "Phoneless/Houseless Voter count: #{voters.where('phone IS NULL or phone = ""').count} / #{voters.where('household_id IS NULL').count}"
        campaign.dial_queue.cache_all(voters.where('phone IS NOT NULL AND household_id IS NOT NULL'))
      else
        p "Skip seeding DialQueue Campaign[#{campaign_id}] DisabledList[#{voter_list_id}] Voter[#{lower_voter_id}..#{upper_voter_id}]"
      end
    end
  end
end