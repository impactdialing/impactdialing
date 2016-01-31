require 'repair'

namespace :duplicate_leads do
  def redis
    Repair.redis
  end

  def each_active_campaign(account_ids, &block)
    Repair.each_active_campaign(account_ids, &block)
  end

  def all_phone_numbers(campaign)
    Repair.all_phone_numbers(campaign)
  end

  desc "Remove duplicate leads from redis households & duplicate Voter records from SQL"
  task :fix,[:account_ids] => :environment do |t,args|
    account_ids = args[:account_ids].split(':')

    # when duplicates detected
    #   and none have a sql_id
    #     remove all but the first
    #       for each duplicate removed
    #         decrement VoterList#stats.total_leads
    #         decrement Campaign#stats.total_leads
    #   and any have a sql_id
    #     remove all without a sql_id
    #       for each duplicate removed
    #         decrement VoterList#stats.total_leads
    #         decrement Campaign#stats.total_leads
    #     when one or more have been completed
    #       keep the first completed
    #       remove the remaining duplicates
    #         for each duplicate removed
    #           decrement VoterList#stats.total_leads
    #           decrement Campaign#stats.total_leads
    #       when the household leads are all completed
    #         mark household completed
    #           move phone to completed set
    #           remove phone from available(:active, :presented) and recycle_bin
    #
    # when empty household detected
    #   del household hash
    #   rem phone from available(:active, :presented), recycle_bin, blocked, completed(:completed, :failed)
    #   decrement VoterList#stats.total_numbers
    #
    # update Campaign#stats.total_numbers
    # update VoterList#stats.total_leads

    each_active_campaign(account_ids) do |campaign|
      p "Fixing Campaign[#{campaign.id}] Account[#{campaign.account_id}]"

      total_leads_removed = 0
      list_leads_removed  = {}
      households          = campaign.dial_queue.households
      phone_numbers       = all_phone_numbers(campaign)
      counts              = {}

      phone_numbers.each do |phone|
        repair = Repair::DuplicateLeads.new(campaign.dial_queue, phone)
        repair.fixit
        if repair.counts[:removed_by_list].values.any?
          total_leads_removed += repair.counts[:removed_by_list].values.inject(:+)
          repair.counts[:removed_by_list].each do |list_id, count|
            counts[ list_id ] ||= 0
            counts[ list_id ] += count
          end
        end
      end

      p "Removed #{total_leads_removed}"

      if total_leads_removed > 0
        # update campaign stats
        key = campaign.call_list.stats.key
        new_count = campaign.call_list.stats[:total_leads] - total_leads_removed
        redis.hset key, 'total_leads', new_count
      end
      # update list stats
      counts.each do |list_id, removed|
        list = campaign.voter_lists.find(list_id)
        key  = list.stats.key
        new_count = list.stats[:total_leads] - removed
        redis.hset key, 'total_leads', new_count

        new_count = list.stats[:new_leads] - removed
        redis.hset key, 'new_leads', new_count
      end
    end # each_active_campaign
  end # task

  desc "Report any leads with duplicate UUIDs"
  task :verify, [:account_ids] => :environment do |t,args|
    account_ids = args[:account_ids].split(':')

    print "AccountID, CampaignID, Phone, Status\n"
    # AccountID, CampaignID, Phone, Status
    each_active_campaign(account_ids) do |campaign|
      report = []
      phone_numbers = all_phone_numbers(campaign)

      phone_numbers.each do |phone|
        status = []
        repair = Repair::DuplicateLeads.new(campaign.dial_queue, phone)

        if repair.any_duplicate_leads?
          status << "DuplicateLeads"

          if repair.household_record.present?
            voter_ids = repair.household_record.voters.pluck :id
            lead_ids  = repair.household[:leads].map{|lead| lead[:sql_id]}

            if voter_ids.any?{|id| not lead_ids.include?(id)}
              status << "DuplicateVoters"
            end
          end
        end

        unless status.empty?
          report << [
            campaign.account_id,
            campaign.id,
            phone,
            status.join('; ')
          ]
        end
      end

      unless report.empty?
        print report.map{|row| row.join(', ')}.join("\n")
      end
    end
  end
end
