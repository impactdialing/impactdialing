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

desc "Verify list enabled/disabled"
task :verify_list_enabled_flag, [:campaign_id] => :environment do |t,args|
  redis = Redis.new
  campaign_id = args[:campaign_id]
  report = -> (match) {
    redis.scan_each(match: match) do |key|
      houses = redis.hgetall key
      houses.each do |ph, _house|
        house = JSON.parse(_house)
        house['leads'].each do |lead|
          p "Sequence     List ID          Phone"
          p "#{lead['sequence']}             #{lead['voter_list_id']}          #{lead['phone']}"
        end
      end
    end
  }
  p "Inactive Leads"
  match = "dial_queue:#{campaign_id}:households:inactive:*"
  report.call(match)

  p "Active Leads"
  match = match.gsub(':inactive:',':active:')
  report.call(match)
end

desc "Count houses in deprecated format"
task :count_deprecated_formats => :environment do
  redis            = Redis.new
  deprecated_house = 0
  total_house      = 0
  good_house       = 0

  redis.scan_each(match: 'dial_queue:*:households:*') do |key|
    next unless redis.type(key) == 'hash'

    hashes = redis.hgetall(key)
    hashes.each do |phone_suffix,house|
      house = JSON.parse(house)
      total_house += 1
      if house.kind_of? Array
        deprecated_house += 1
      else
        good_house += 1
      end
    end
  end

  p "Deprecated: #{deprecated_house}"
  p "Good: #{good_house}"
  p "Total: #{total_house}"
end

desc "Delete houses in deprecated format"
task :delete_deprecated_formats => :environment do
  redis            = Redis.new
  deprecated_house = 0
  total_house      = 0
  good_house       = 0

  redis.scan_each(match: 'dial_queue:*:households:*') do |key|
    next unless redis.type(key) == 'hash'

    hashes = redis.hgetall(key)
    hashes.each do |phone_suffix,house|
      house = JSON.parse(house)
      total_house += 1
      if house.kind_of? Array
        deprecated_house += 1
        redis.hdel key, phone_suffix
      else
        good_house += 1
      end
    end
  end

  p "Deprecated: #{deprecated_house}"
  p "Good: #{good_house}"
  p "Total: #{total_house}"
end

desc "Search all redis households & leads for given UUID"
task :search_uuid, [:campaign_id, :uuid] => :environment do |t,args|
  uuid             = args[:uuid]
  campaign_id      = args[:campaign_id]
  redis            = Redis.new
  house_matches    = []
  lead_matches     = []
  corrupt_house    = []
  corrupt_lead     = []
  deprecated_house = 0
  matcher          = 'dial_queue:*:households:*'

  if campaign_id.present?
    matcher = "dial_queue:#{campaign_id}:households:*"
  end

  redis.scan_each(match: matcher) do |key|
    next unless redis.type(key) == 'hash'

    hashes = redis.hgetall(key)
    hashes.each do |phone_suffix,house|
      if house.blank?
        print '-'
        next
      end

      house = JSON.parse(house)

      if house.kind_of? Array
        deprecated_house += 1
        #print "@"
        #print "#{phone_suffix} => #{house}\n"
        next
      end

      unless house.keys.include?('uuid')
        corrupt_house << house
        print "!"
        next
      end

      if house['uuid'] == uuid
        house_matches << house
        print "\nHouse: #{house}\n"
        exit
      elsif house['leads'].any?
        begin

        house['leads'].each do |lead|
          unless lead.keys.include?('uuid')
            corrupt_lead << lead
            print "#"
            next
          end
          if lead['uuid'] == uuid
            lead_matches << lead
            print "\nLead: #{lead}\n"
            exit
          end
        end
        rescue => e
          byebug
        end
      end 
      print '.'
    end
  end

  print "\n\n"
  print "Found #{house_matches.size} House matches\n"
  print "Found #{lead_matches.size} Lead matches\n"
  print "Found #{corrupt_house.size} Corrupt households\n"
  print "Found #{corrupt_lead.size} Corrupt leads\n"
  print "Found #{deprecated_house} Houses in deprecated format\n"
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

desc "Cache selected Script fields"
task :seed_script_fields => :environment do
  Script.find_in_batches do |scripts|
    scripts.each do |script|
      Resque.enqueue(CallFlow::Web::Jobs::CacheContactFields, script.id)
    end
  end
end

desc "Refresh Redis Wireless Block List & Wireless <-> Wired Ported Lists"
task :refresh_wireless_ported_lists => :environment do |t,args|
  DoNotCall::Jobs::RefreshWirelessBlockList.perform('nalennd_block.csv')
  DoNotCall::Jobs::RefreshPortedLists.perform
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
    'close',
    'fix',
    'complete',
    'deliver',
    'improve',
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
