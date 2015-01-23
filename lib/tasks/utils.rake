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
  require 'householding/migrate'
  # Account#activated: now meaningless, all accounts created in last year => false
  # account_ids = Account.all.pluck(:id)
  # campaign_ids = Campaign.pluck(:id)
  # voter_count = 0
  # campaign_ids = Campaign.where('created_at > ?', 7.months.ago.beginning_of_month).where(active: true).pluck(:id)
  # campaign_ids.each_slice(10){ |ids| voter_count += Voter.where(campaign_id: ids).with_enabled(:list).count(:campaign_id); p voter_count}
  # voter_count = 0
  # campaign_ids.each_slice(10){ |ids| voter_count += Voter.where(campaign_id: ids).count(:campaign_id); p voter_count}
  # voters to process (production): 16,151,793 over 3,156 active (not deleted) campaigns
  # for every voter in an active account and active campaign
  # - find or create a household
  #   - phone       = Voter#phone
  #   - blocked     = [:dnc, :cell] <= Voter#blocked & VoterList#skip_wireless
  #   - account_id  = Voter#account_id
  #   - campaign_id = Voter#campaign_id
  # - update Voter#household_id
  # - update Voter#enabled, removing :blocked from all
  # - refresh Household#voters_count
  # - refresh Campaign#households_count
  # for every created household
  # - find most recent call attempt across members of the household
  # - update status w/ most recent call attempt status
  # - update presented_at w/ most recent call attempt
  quota_account_ids        = Quota.where(disable_access: false).pluck(:account_id)
  subscription_account_ids = Billing::Subscription.where(
    'plan IN (?) OR (plan IN (?) AND provider_status = ?)',
    ['trial', 'per_minute', 'enterprise'],
    ['basic', 'pro', 'business'],
    'active'
  ).pluck(:account_id)
  account_ids = (quota_account_ids + subscription_account_ids).uniq
  Campaign.where(account_id: account_ids).where('created_at > ?', 6.months.ago.beginning_of_month).find_in_batches(batch_size: 10) do |campaigns|
    p "Migrating Campaigns[#{campaigns.map(&:id)}]"
    p "AccountRange[#{campaigns.first.account_id}..#{campaigns.last.account_id}]"
    p "CreatedAtRange[#{campaigns.first.created_at}..#{campaigns.last.created_at}]"

    Householding::Migrate.voters(campaigns)

    p "Household count by campaign id: #{Household.group(:campaign_id).count}"
    p "======================================================================"
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
