module Householding
end

class Householding::Migrate
  def self.voters(campaigns)
    campaigns.each do |campaign|
      p "Campaign: #{campaign.name}"
      tally = 0
      campaign.all_voters.where('household_id IS NULL AND phone IS NOT NULL').includes(:voter_list, :call_attempts).find_in_batches(batch_size: 500) do |voters|
        p "- Processing #{tally}-#{tally += 500}"
        last_household      = campaign.households.order('id desc').first
        households          = []
        updated_households  = []
        call_attempts       = []
        last_call_attempt   = nil

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

        import = Household.import households
        if import.failed_instances.any?
          p "- Household.import"
          p "- Instances failed"
          print import.failed_instances.map{|i| [i.errors.full_messages]}.uniq.join("\n")
          exit
        end
        households             = nil
        household_ids_by_phone = {}
        campaign.households.select('id, phone').each{|h| household_ids_by_phone[h.phone] = h.id}

        updated_voters = voters.map do |voter|
          household_id = household_ids_by_phone[voter.phone]
          if household_id.blank?
            p "- Loading single Household for Phone[#{voter.phone}] Voter[#{voter.id}]"
            household    = campaign.households.where(phone: voter.phone).first
            household_id = household.id
            if household_id.blank?
              p "- Household id still blank: Voter[#{voter}]"
              exit
            end
          end
          enabled            = calculate_enabled(voter)
          voter.household_id = household_id
          voter.enabled      = enabled

          voter.call_attempts.each do |call_attempt|
            call_attempt.household_id = household_id
            call_attempts << call_attempt
          end

          voter
        end
        household_ids_by_phone = {}

        import         = Voter.import updated_voters, on_duplicate_key_update: [:household_id, :enabled]
        updated_voters = nil
        if import.failed_instances.any?
          p "- Voter.import"
          p "- Instances failed"
          print import.failed_instances.map{|i| [i.errors.full_messages]}.uniq.join("\n")
          exit
        end

        import        = CallAttempt.import call_attempts, on_duplicate_key_update: [:household_id]
        call_attempts = []
        if import.failed_instances.any?
          p "- CallAttempt.import"
          p "- Instances failed"
          print import.failed_instances.map{|i| [i.errors.full_messages]}.uniq.join("\n")
          exit
        end
      end
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