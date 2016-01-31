namespace :dial_queue do
  namespace :inflight_stats do
    def inflight_stats
      redis    = Redis.new
      base_key = "inflight_stats"
      keys     = redis.keys "#{base_key}:*"
      stats    = []

      redis.scan_each(match: "#{base_key}:*") do |key|
        id = key.split(':')[1].to_i
        dqakey = ['dial_queue', id, 'active'].join(':')
        dqpkey = ['dial_queue', id, 'presented'].join(':')
        dqrkey = ['dial_queue', id, 'bin'].join(':')
        stats << [
          id, redis.hget(key, 'ringing'), redis.hget(key, 'presented'),
          redis.zcard(dqakey), redis.zcard(dqpkey), redis.zcard(dqrkey)
        ]
      end

      return stats
    end

    def print_inflight_stats
      print "Campaign,Ringing count,Presented count,DQ Available,DQ Presented,DQ Bin\n"
      print inflight_stats.map{|row| row.join(',')}.join("\n") + "\n"
    end

    desc "Generate CSV report of current inflight_stats"
    task :report => [:environment] do
      print_inflight_stats
    end

    desc "Reset all inflight stats to zero"
    task :reset,[:campaign_id] => [:environment] do |t,args|
      print "BEFORE\n"
      print_inflight_stats
      print "-----\n"
      campaign_id = args[:campaign_id]
      redis       = Redis.new
      base_key    = "inflight_stats"
      hash_args   = [:ringing, 0, :presented, 0]

      if campaign_id.present?
        key = [base_key, campaign_id].join(':')
        redis.hmset(key, *hash_args)
      else
        inflight_stats.each do |campaign_stats|
          key = [base_key, campaign_stats[0]].join(':')
          redis.hmset(key, *hash_args)
        end
      end
      print "AFTER\n"
      print_inflight_stats
    end
  end

  namespace :households do
    def collect_completed_from(phone_set, households, name)
      completed = []
      phone_set.each(name) do |phone_score|
        phone, score = *phone_score
        if households.incomplete_lead_count_for(phone).zero?
          completed << phone_score.reverse
        end
      end

      return completed
    end

    def shift_completed(source_set, completed_set, items)
      return if items.blank?
      entries = items.map(&:last)
      redis.multi do
        redis.zrem source_set, items.map(&:last)
        redis.zadd completed_set, items
      end
    end

    desc "Search available & recycle bin sets for completed numbers and move them to the completed set"
    task :harvest_completed,[:campaign_id] => [:environment] do |t,args|
      campaign_id   = args[:campaign_id]
      campaign      = Campaign.find campaign_id
      dial_queue    = campaign.dial_queue
      completed_key = dial_queue.completed.keys[:completed]

      completed = collect_completed_from(dial_queue.available, dial_queue.households, :active)
      shift_completed(dial_queue.available.keys[:active], completed_key, completed)
      p "Removing #{completed.size} phones from Available:active and adding to Completed"
      p "active = #{completed}" if completed.size > 0

      completed  = collect_completed_from(dial_queue.available, dial_queue.households, :presented)
      shift_completed(dial_queue.available.keys[:presented], completed_key, completed)
      p "Removing #{completed.size} phones from Available:presented and adding to Completed"
      p "presented = #{completed}" if completed.size > 0

      completed = collect_completed_from(dial_queue.recycle_bin, dial_queue.households, :bin)
      shift_completed(dial_queue.recycle_bin.keys[:bin], completed_key, completed)
      p "Removing #{completed.size} phones from RecycleBin and adding to Completed"
      p "bin = #{completed}" if completed.size > 0
    end

    desc "Search available & recycle bin sets for completed numbers and print report"
    task :report_completed_and_available,[:campaign_id] => [:environment] do |t,args|
      campaign_id = args[:campaign_id]
      campaign    = Campaign.find campaign_id
      dial_queue  = campaign.dial_queue

      completed   = collect_completed_from(dial_queue.available, dial_queue.households, :active)
      p "Found #{completed.size} phones from Available:active."
      completed  = collect_completed_from(dial_queue.available, dial_queue.households, :presented)
      p "Found #{completed.size} phones from Available:presented."
      completed = collect_completed_from(dial_queue.recycle_bin, dial_queue.households, :bin)
      p "Found #{completed.size} phones from RecycleBin:bin."
    end

    desc "Locate campaigns with available & completed numbers"
    task :report_campaigns_with_completed_and_available => [:environment] do |t,args|
      borked = []
      reports = []
      Repair.each_active_campaign do |campaign|
        dial_queue = campaign.dial_queue
        completed = collect_completed_from(dial_queue.available, dial_queue.households, :active)
        completed += collect_completed_from(dial_queue.available, dial_queue.households, :presented)
        completed += collect_completed_from(dial_queue.recycle_bin, dial_queue.households, :bin)
        if completed.flatten.any?
          borked << campaign.id
          reports << completed.flatten
        end
      end
      p "Found #{borked.size} borked campaigns."
      borked.each_with_index do |campaign_id, i|
        p "Campaign #{campaign_id}"
        p "Report #{i}: #{reports[i].size}"
      end
    end

    desc "Locate empty households (households with no leads)"
    task :report_empty => [:environment] do |t,args|
      print "AccountID, CampaignID, Phone, Status\n"
      Repair.each_active_campaign do |campaign|
        report = []
        Repair.all_phone_numbers(campaign).each do |phone|
          repair = Repair::EmptyHouseholds.new(campaign.dial_queue, phone)
          
          if repair.empty?
            report << [
              campaign.account_id,
              campaign.id,
              phone,
              "Invalid House"
            ]
          else
            if repair.leads_empty?
              report << [
                campaign.account_id,
                campaign.id,
                phone,
                "No Leads"
              ]
            end
          end
        end

        unless report.empty?
          print report.map{|row| row.join(',')}.join("\n")
        end
      end
    end
  end
end
