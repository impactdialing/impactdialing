require 'librato_resque'

module Householding
  class Migrate
    include Resque::Plugins::UniqueJob
    extend LibratoResque
    @queue = :migrating

    def self.perform(account_id, campaign_id, lower_voter_id, upper_voter_id)
      campaign = Campaign.where(account_id: account_id, id: campaign_id).first

      p "Householding::Migrate.perform[START] Voters[#{lower_voter_id}..#{upper_voter_id}] on Campaign[id:#{campaign.id}[name:#{campaign.name}]"

      stats = process_voters(campaign, lower_voter_id, upper_voter_id)

      p "Householding::Migrate stats Households[#{stats[:households]}] CallAttempts[#{stats[:call_attempts]}] ProcessedVoters[#{stats[:processed_voters]}] UpdatedVoters[#{stats[:updated_voters]}]"
      p "Householding::Migrate.perform[END] Voters[#{lower_voter_id}..#{upper_voter_id}] on Campaign[id:#{campaign.id}][name:#{campaign.name}]"
    end

    def self.process_voters(campaign, lower_voter_id, upper_voter_id)
      stats = {
        households:       0,
        call_attempts:    0,
        processed_voters: 0,
        updated_voters:   0,
        cache_count:      0
      }
      voters = campaign.all_voters.where(id: (lower_voter_id..upper_voter_id)).includes(:voter_list, :call_attempts, :campaign).where('household_id IS NULL AND phone IS NOT NULL')
      stats[:processed_voters] = voters.count
      households               = []
      call_attempts            = []
      last_call_attempt        = nil

      voters.each do |voter|
        if campaign.households.where(phone: voter.phone).count.zero?
          last_call_attempt = voter.call_attempts.order('id desc').first

          households << campaign.households.build({
            account_id:   voter.account_id,
            phone:        voter.phone,
            blocked:      calculate_blocked(campaign, voter),
            presented_at: last_call_attempt.try(:created_at),
            status:       last_call_attempt.try(:status) || Voter::Status::NOTCALLED
          })
        end
      end

      stats[:households] = households.size
      import = Household.import households
      log_if_any_failed(import, 'Household')
      households             = []

      household_ids_by_phone = {}
      campaign.households.select('id, phone').each{|h| household_ids_by_phone[h.phone] = h.id}

      updated_voters = voters.map do |voter|
        household_id = household_ids_by_phone[voter.phone]
        if household_id.blank?
          household    = campaign.households.where(phone: voter.phone).first
          household_id = household.try(:id)
          if household_id.blank?
            p "Householding::Migrate::DataError Household not found for Phone[#{voter.phone}] Campaign[#{campaign.id}] Voter[id:#{voter.id}][status:#{voter.status}]"
          end
        end
        enabled            = calculate_enabled(voter)
        voter.household_id = household_id
        voter.enabled      = enabled

        voter.call_attempts.each do |call_attempt|
          if household_id.present?
            call_attempt.household_id = household_id
            call_attempts << call_attempt
          end
        end

        if voter.household_id.present?
          voter
        else
          nil
        end
      end.compact

      stats[:updated_voters] = updated_voters.size
      import         = Voter.import updated_voters, on_duplicate_key_update: [:household_id, :enabled]
      updated_voters = nil
      raise_if_any_failed(import, 'Voter')

      stats[:call_attempts] = call_attempts.size
      import        = CallAttempt.import call_attempts, on_duplicate_key_update: [:household_id]
      call_attempts = []
      raise_if_any_failed(import, 'CallAttempt')

      Campaign.reset_counters(campaign.id, :households)
      household_ids_by_phone.values.each do |household_id|
        Household.reset_counters(household_id, :voters)
      end

      last_campaign_call_attempt = campaign.call_attempts.order('id DESC').first
      if campaign.active? and (campaign.updated_at > 90.days.ago or (last_campaign_call_attempt.present? and last_campaign_call_attempt.created_at > 90.days.ago))
        Voter.where(campaign_id: campaign.id, id: (lower_voter_id..upper_voter_id)).where('household_id IS NOT NULL').with_enabled(:list).find_in_batches do |migrated_voters|
          campaign.dial_queue.cache_all(migrated_voters)
        end

        stats[:cache_count] = campaign.dial_queue.available.size + campaign.dial_queue.recycle_bin.size
      end

      return stats
    end

    def self.raise_if_any_failed(import, type)
      if import.failed_instances.any?
        log_if_any_failed(import, type)
        
        raise "Householding::Migrate::ImportError #{messages.join("\n")}"
      end
    end

    def self.log_if_any_failed(import, type)
      if import.failed_instances.any?
        messages = [
          "#{type}.import",
          "#{import.failed_instances.size} InstancesFailed",
          import.failed_instances.map{|i| [i.errors.full_messages]}.uniq.join("; ")
        ]
        p messages.join("\n")
      end
    end

    def self.calculate_blocked(campaign, voter)
      phone   = voter.phone
      blocked = []
      if voter.voter_list.skip_wireless? && dnc_wireless.prohibits?(phone)
        blocked << :cell
      end
      if campaign.blocked_numbers.include?(phone)
        blocked << :dnc
      end
      Household.bitmask_for_blocked( *blocked )
    end

    def self.calculate_enabled(voter)
      if voter.voter_list.enabled?
        Voter.bitmask_for_enabled( *[:list] )
      else
        Voter.bitmask_for_enabled( *[] )
      end
    end

    def self.dnc_wireless
      @dnc_wireless ||= DoNotCall::WirelessList.new
    end
  end
end
