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

desc "Create Households w/ relevant Voter data & update relevant Voter#household_id & CallAttempt#household_id"
task :migrate_householding => :environment do
  priority_account_ids = [
    1277, 1165, 1153, 1278, 781, 978, 1159, 1297, 850,
    1286, 1173, 399, 298, 1294, 121, 224, 244, 268, 487,
    525, 558, 598, 875, 1283, 94, 159, 1264, 899, 34
  ]

  VoterList.where('account_id NOT IN (?)', priority_account_ids).order('created_at desc').includes(:campaign).find_in_batches(batch_size: 100) do |voter_lists|
    print 'b'
    voter_lists.each do |voter_list|
      voter_list.voters.where('household_id IS NULL AND phone IS NOT NULL').find_in_batches(batch_size: 1000) do |voters|
        lower_voter_id = voters.first.id
        upper_voter_id = voters.last.id
        Resque.enqueue(Householding::Migrate, voter_list.account_id, voter_list.campaign_id, lower_voter_id, upper_voter_id)
        print 'q'
      end
    end
    print "\n"
  end
end

desc "Migrate priority accounts to Householding"
task :migrate_householding_priority => :environment do
  account_ids = [
    1277, 1165, 1153, 1278, 781, 978, 1159, 1297, 850,
    1286, 1173, 399, 298, 1294, 121, 224, 244, 268, 487,
    525, 558, 598, 875, 1283, 94, 159, 1264, 899, 34
  ]

  account_ids.each do |account_id|
    VoterList.where(account_id: account_id).includes(:campaign).find_in_batches(batch_size: 100) do |voter_lists|
      print 'b'
      voter_lists.each do |voter_list|
        voter_list.voters.where('household_id IS NULL AND phone IS NOT NULL').find_in_batches(batch_size: 1000) do |voters|
          lower_voter_id = voters.first.id
          upper_voter_id = voters.last.id
          Resque.enqueue(Householding::Migrate, voter_list.account_id, voter_list.campaign_id, lower_voter_id, upper_voter_id)
          print 'q'
        end
      end
      print "\n"
    end
  end
end

desc "Update Householding related counter caches"
task :update_householding_counter_cache => :environment do
  quota_account_ids        = Quota.where(disable_access: false).pluck(:account_id)
  subscription_account_ids = Billing::Subscription.where(
    'plan IN (?) OR (plan IN (?) AND provider_status = ?)',
    ['trial', 'per_minute', 'enterprise'],
    ['basic', 'pro', 'business'],
    'active'
  ).pluck(:account_id)
  account_ids = (quota_account_ids + subscription_account_ids).uniq
  Campaign.where(account_id: account_ids).where('created_at > ?', 6.months.ago.beginning_of_month).find_in_batches(batch_size: 100) do |campaigns|
    campaigns.each do |campaign|
      p "Resetting Campaign[#{campaign.id}].households_count"
      Resque.enqueue(Householding::ResetCounterCache, 'campaign', campaign.id)
      campaign.households.find_in_batches(batch_size: 500) do |households|
        print '.'
        Resque.enqueue(Householding::ResetCounterCache, 'households', campaign.id, households.first.id, households.last.id)
      end
      p "--"
    end
  end
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
  quota_account_ids        = Quota.where(disable_access: false).pluck(:account_id)
  subscription_account_ids = Billing::Subscription.where(
    'plan IN (?) OR (plan IN (?) AND provider_status = ?)',
    ['trial', 'per_minute', 'enterprise'],
    ['basic', 'pro', 'business'],
    'active'
  ).pluck(:account_id)
  account_ids = (quota_account_ids + subscription_account_ids).uniq

  VoterList.where(account_id: account_ids).where('created_at > ?', 6.months.ago.beginning_of_month).includes(:campaign).find_in_batches(batch_size: 100) do |voter_lists|
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

desc "Migrate Voter#voicemail_history to CallAttempt#recording_id & #recording_delivered_manually"
task :migrate_voicemail_history => :environment do
  voters = Voter.includes(:call_attempts).where('status != "not called"').where('voicemail_history is not null')

  dirty = []
  voters.each do |voter|
    call_attempt = voter.call_attempts.first
    recording_id = voter.voicemail_history.split(',').first

    call_attempt.recording_id = recording_id
    call_attempt.recording_delivered_manually = false
    dirty << call_attempt
  end

  puts CallAttempt.import(dirty, {
      :on_duplicate_key_update => [:recording_id, :recording_delivered_manually]
  })
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
