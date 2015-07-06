## Example script to pull recordings for given list of phone numbers
#
# account = Account.find xxx
# phone_numbers = ['xxx','yyy']
# voters = account.voters.where(phone: phone_numbers)
# out = ''
# voters.each do |v|
#   out << "#{v.phone}\n"
#   call_attempts = v.call_attempts.where('recording_url is not null').order('voter_id DESC')
#   call_attempts.each do |ca|
#     out << "- #{ca.tStartTime.strftime('%m/%d/%Y at %I:%M%P')} #{ca.recording_url}\n"
#   end
# end
# print out

desc "Migrate DialQueue::Households schema for memory optimization"
task :migrate_dial_queue_households => [:environment] do
  # migrate redis households
  #
  time_threshold                = 30.days.ago.beginning_of_day
  recently_called_campaign_ids  = CallAttempt.where('created_at > ?', time_threshold).select('DISTINCT(campaign_id)').pluck(:campaign_id).uniq
  recently_created_campaign_ids = Campaign.where('created_at > ?', time_threshold).where(active: true).pluck(:id).uniq
  campaign_ids                  = recently_called_campaign_ids + recently_created_campaign_ids
  campaigns                     = Campaign.where(id: campaign_ids.uniq)
  redis                         = Redis.new

  p "Updating redis config"
  redis.config(:set, 'hash-max-ziplist-entries', 1024)
  redis.config(:set, 'hash-max-ziplist-value', 512)

  p "Loaded: #{campaigns.count} campaigns"

  campaigns.each do |campaign|
    next unless campaign.active? or campaign.dial_queue.exists?

    p "Migrating: #{campaign.name}"
    p "- #{campaign.households.count} households"
    base_key = "dial_queue:#{campaign.id}:households:active"
    phones   = campaign.households.pluck(:phone)

    phones.each do |phone|
      p "- #{phone}"
      current_key  = "#{base_key}:#{phone[0..4]}"
      current_hkey = "#{phone[5..-1]}"
      new_key      = "#{base_key}:#{phone[0..-4]}"
      new_hkey     = "#{phone[-3..-1]}"

      redis.watch(current_key) do
        household_json = redis.hget current_key, current_hkey

        next if household_json.nil?

        redis.multi do
          redis.hset new_key, new_hkey, household_json
          redis.hdel current_key, current_hkey
        end
      end
    end
  end
end

desc "Update VoterList Household Counter Caches [not the default rails-way]"
task :update_list_household_counts => :environment do
  quota_account_ids        = Quota.where(disable_access: false).pluck(:account_id)
  subscription_account_ids = Billing::Subscription.where(
    'plan IN (?) OR (plan IN (?) AND provider_status = ?)',
    ['trial', 'per_minute', 'enterprise'],
    ['basic', 'pro', 'business'],
    'active'
  ).pluck(:account_id)

  account_ids = (quota_account_ids + subscription_account_ids).uniq
  failed      = []
  updated     = 0
  skipped     = 0
  VoterList.where(account_id: account_ids).find_in_batches(batch_size: 100) do |lists|
    lists.each do |list|
      current_count         = list.households_count
      households_count      = list.voters.select('DISTINCT household_id').count
      list.households_count = households_count

      if current_count != households_count
        if list.save
          print '.'
          updated += 1
        else
          print "x"
          failed << list.id
        end
      else
        print '-'
        skipped += 1
      end
    end
  end
  print "\nDone!\n"

  p "Skipped: #{skipped}"
  p "Updated: #{updated}"
  p "Failed: #{failed.size}"
  p "Failed List IDs: #{failed.join(',')}"
end

desc "Patch all campaigns with corrupted caches"
task :patch_corrupt_dial_queues => :environment do
  corrupt_count = 0

  Campaign.where('created_at > ?', 6.months.ago.beginning_of_month).each do |campaign|
    campaign.dial_queue.available.all.each do |phone|
      if campaign.dial_queue.households.find(phone).empty?
        corrupt_count += 1
        campaign.dial_queue.available.remove(phone)
        campaign.dial_queue.recycle_bin.remove(phone)
        unless campaign.dial_queue.households.missing?(phone)
          campaign.dial_queue.households.remove_house(phone)
        end
      end
    end
  end
  
  print "\n\nFound & patched #{corrupt_count} corrupted dial queues\n\n"
end

desc "Patch given campaign if cache is corrupted"
task :patch_corrupt_dial_queue, [:campaign_id] => :environment do |t,args|
  corrupt_count = 0
  campaign      = Campaign.find(args[:campaign_id])

  campaign.dial_queue.available.all.each do |phone|
    if campaign.dial_queue.households.find(phone).empty?
      corrupt_count += 1
      campaign.dial_queue.available.remove(phone)
      campaign.dial_queue.recycle_bin.remove(phone)
      unless campaign.dial_queue.households.missing?(phone)
        campaign.dial_queue.households.remove_house(phone)
      end
    end
  end
  
  print "\n\nFound & patched #{corrupt_count} corrupted dial queues\n\n"
end

desc "Sweep up dial queue cache of any data from campaigns inactive since :days ago"
task :sweep_dial_queue, [:days] => :environment do |t,args|
  days           = (args[:days] || 90).to_i
  time_threshold = days.days.ago
  purged_total   = {}
  available      = {}
  accounts       = {}

  recently_called_campaign_ids = CallAttempt.where('created_at > ?', time_threshold).select('DISTINCT(campaign_id)').pluck(:campaign_id)

  Campaign.where(active: true).
    where('updated_at < ?', time_threshold).
    where('id NOT IN (?)', recently_called_campaign_ids).
    find_in_batches(batch_size: 500) do |campaigns|
      campaigns.each do |campaign|
        accounts[campaign.id]     = campaign.account_id
        purged_total[campaign.id] = campaign.dial_queue.purge
      end
    end

  Campaign.where(id: recently_called_campaign_ids).find_in_batches(batch_size: 500) do |campaigns|
    campaigns.each do |campaign|
      accounts[campaign.id]  = campaign.account_id
      available[campaign.id] = campaign.dial_queue.available.size
    end
  end
  print "\nDone!\n"
  print "\nInactive/Purged Report\n"
  print "Account ID,Campaign ID,#s Purged\n"
  purged_total.each do |k,v|
    print "#{accounts[k]},#{k},#{v}\n"
  end

  print "\nActive/Available Report\n"
  print "Account ID,Campaign ID,#s Available\n"
  available.each do |k,v|
    print "#{accounts[k]},#{k},#{v}\n"
  end
end

desc "Rebuild dial queue cache"
task :rebuild_dial_queues => :environment do |t,args|
  VoterList.includes(:campaign).find_in_batches(batch_size: 100) do |voter_lists|
    print 'b'
    voter_lists.each do |voter_list|
      next if voter_list.voters.count.zero?

      lower_voter_id = voter_list.voters.order('id asc').first.id
      upper_voter_id = voter_list.voters.order('id desc').first.id
      Resque.enqueue(Householding::SeedDialQueue, voter_list.campaign_id, voter_list.id, lower_voter_id, upper_voter_id)
      print 'q'
    end
  end
  print "\n\nDone!!\n\n"
end

desc "Rebuild dial queue for a specific campaign"
task :rebuild_dial_queue => :environment do |t,args|
  campaign_id = args[:campaign_id]
  campaign    = Campaign.find(campaign_id)
  campaign.all_voters.with_enabled(:list).find_in_batches(batch_size: 500) do |voters|
    campaign.dial_queue.cache_all(voters)
  end
end

desc "Cache households to dial queue"
task :seed_dial_queue => :environment do
  quota_account_ids        = Quota.where(disable_access: false).pluck(:account_id)
  subscription_account_ids = Billing::Subscription.where(
    'plan IN (?) OR (plan IN (?) AND provider_status = ?)',
    ['trial', 'per_minute', 'enterprise'],
    ['basic', 'pro', 'business'],
    'active'
  ).pluck(:account_id)
  account_ids = (quota_account_ids + subscription_account_ids).uniq
  Campaign.where(account_id: account_ids).where('created_at > ?', 6.months.ago.beginning_of_month).includes(:voter_lists).find_in_batches(batch_size: 100) do |campaigns|
    campaigns.each do |campaign|
      p "Seeding DialQueue Account[#{campaign.account_id}] Campaign[#{campaign.name}]"
      campaign.voter_lists.each do |voter_list|
        if voter_list.enabled?
          voter_list.voters.find_in_batches(batch_size: 500) do |voters|
            Resque.enqueue(Householding::SeedDialQueue, campaign.id, voter_list.id, voters.first.id, voters.last.id)
          end
          print '.'
        end
      end
      p "--"
    end
    print "\n\nDone!!\n"
  end
end

desc "Cache selected Script fields"
task :seed_script_fields => :environment do
  Script.find_in_batches do |scripts|
    scripts.each do |script|
      Resque.enqueue(CallFlow::Web::Jobs::CacheContactFields, script.id)
    end
  end
end

desc "sync Voters#enabled w/ VoterList#enabled"
task :sync_all_voter_lists_to_voter => :environment do |t, args|
  limit  = 100
  offset = 0
  lists  = VoterList.limit(limit).offset(offset)
  rows   = []

  until lists.empty?
    print "#{1 + offset} - #{offset + limit}\n"
    lists.each do |list|
      row = []
      row << list.id
      if list.enabled?
        row << list.voters.count - list.voters.enabled.count
        row << 0
      else
        row << 0
        row << list.voters.count - list.voters.disabled.count
      end
      bits = []
      bits << :list if list.enabled?
      blocked_bit     = Voter.bitmask_for_enabled(*[bits + [:blocked]].flatten)
      not_blocked_bit = Voter.bitmask_for_enabled(*bits)

      list.voters.blocked.update_all(enabled: blocked_bit)
      list.voters.not_blocked.update_all(enabled: not_blocked_bit)
      if list.enabled?
        row << list.voters.enabled.count
        row << 0
      else
        row << 0
        row << list.voters.disabled.count
      end

      rows << row
    end

    offset += limit
    lists = VoterList.limit(limit).offset(offset)
  end
  print "List ID, Enabling, Disabling, Total enabled, Total disabled\n"
  print rows.map{|row| row.join(", ")}.join("\n") + "\n"
  print "done\n"
end

desc "Inspect voter blocked ids"
task :inspect_voter_dnc => :environment do |t,args|
  x = Voter.with_enabled(:blocked).group(:campaign_id).count
  y = Voter.without_enabled(:blocked).group(:campaign_id).count
  print "Blocked: #{x}\n"
  print "Not blocked: #{y}\n"
end

desc "Update VoterList voters_count cache"
task :update_voter_list_voters_count_cache => :environment do |t,args|
  VoterList.select([:id, :campaign_id]).find_in_batches do |voter_lists|
    voter_lists.each do |voter_list|
      VoterList.reset_counters(voter_list.id, :voters)
    end
  end
end

desc "Refresh Redis Wireless Block List & Wireless <-> Wired Ported Lists"
task :refresh_wireless_ported_lists => :environment do |t,args|
  DoNotCall::Jobs::RefreshWirelessBlockList.perform('nalennd_block.csv')
  DoNotCall::Jobs::RefreshPortedLists.perform
end

desc "Fix pre-existing VoterList#skip_wireless values"
task :fix_pre_existing_list_skip_wireless => :environment do
  # lists that were never scrubbed => < 2014-10-29
  # lists that were never scrubbed => > 2014-10-29 11:15am < 2014-10-29 12:00pm
  # lists that were scrubbed => > 2014-10-29 3am < 2014-10-29 11:15am
  # lists that were scrubbed => > 2014-10-29 12pm
  never_scrubbed = VoterList.where('created_at <= ? OR (created_at >= ? AND created_at <= ?)',
    '2014-10-29 07:00:00 0000',
    '2014-10-29 18:15:00 0000',
    '2014-10-29 19:15:00 0000')
  never_scrubbed.update_all(skip_wireless: false)
end

desc "Read phone numbers from csv file and output as array."
task :extract_numbers, [:filepath, :account_id, :campaign_id, :target_column_index] => :environment do |t, args|
  # raise "Do Not Do This. BlockedNumber.import will bypass after create hooks, breaking the dialer because then blocked numbers could be dialed."
  require 'csv'

  account_id          = args[:account_id]
  campaign_id         = args[:campaign_id]
  target_column_index = args[:target_column_index].to_i
  filepath            = args[:filepath]
  numbers             = []

  CSV.foreach(File.join(Rails.root, filepath)) do |row|
    numbers << row[target_column_index]
  end

  print "\n"
  numbers.shift # lose the header
  print "numbers = #{numbers.compact}\n"
  print "account = Account.find(#{account_id})\n"
  if campaign_id.present?
    print "campaign = account.campaigns.find(#{campaign_id})\n"
    print "numbers.each{ |number| BlockedNumber.create!({account_id: account.id, campaign_id: campaign.id, number: number}) }\n"
  else
    print "numbers.each{ |number| BlockedNumber.create!({account_id: account.id, number: number}) }\n"
  end
  print "\n"
end

desc "Generate / append to CHANGELOG.md entries within the start_date and end_date"
task :changelog, [:after, :before] do |t, args|
  desired_entries = [
    'changelog',
    'closes',
    'fixes',
    'completes',
    'delivers',
    '#'
  ]
  format = 'format:"%cr%n-----------%n%s%+b%n========================================================================"'
  after = args[:after]
  before = args[:before]
  cmd = 'git log'
  cmd << " --pretty=#{format}"
  desired_entries.each do |de|
    cmd << " --grep='#{de}'"
  end
  cmd << " --after='#{after}'" unless after.blank?
  cmd << " --before='#{before}'" unless before.blank?
  print cmd + "\n"
end

desc "Generate CSV of random, known bad numbers w/ a realistic distribution (eg 2-4 members per household & 85-95%% unique numbers)"
task :generate_realistic_voter_list => :environment do
  require 'forgery'

  today    = Date.today
  
  4.times do |i|
    filepath = File.join(Rails.root, 'tmp', "#{today.year}-#{today.month}-#{today.day}-#{Forgery(:basic).number}-random-part(#{i+1}).csv")
    file     = File.new(filepath, 'w+')
    file << "#{['VANID', 'Phone', 'Last Name', 'First Name', 'Suffix', 'Sex', 'Age', 'Party'].join(',')}\n"
    250_000.times do
    # 5.times do
      row = [
        Forgery(:basic).number(at_least: 1000, at_most: 999999),
        "1#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}",
        Forgery(:name).last_name,
        Forgery(:name).first_name,
        Forgery(:name).suffix,
        %w(Male Female).sample,
        Forgery(:basic).number,
        %w(Republican Democrat Independent).sample
      ]
      file << "#{row.join(',')}\n"
    end
    file.close
  end
end
