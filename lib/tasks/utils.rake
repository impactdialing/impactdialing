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

desc "Read phone numbers from csv file and output as array."
task :extract_numbers, [:filepath, :account_id, :campaign_id, :target_column_index] => :environment do |t, args|
  require 'csv'

  account_id = args[:account_id]
  campaign_id = args[:campaign_id]
  target_column_index = args[:target_column_index].to_i
  filepath = args[:filepath]
  numbers = []

  CSV.foreach(File.join(Rails.root, filepath)) do |row|
    numbers << row[target_column_index]
  end

  print "\n"
  numbers.shift # lose the header
  print "numbers = #{numbers.compact}\n"
  print "account = Account.find(#{account_id})\n"
  if campaign_id.present?
    print "campaign = account.campaigns.find(#{campaign_id})\n"
    print "columns = [:account_id, :campaign_id, :number]\n"
    print "values = numbers.map{|number| [account.id, campaign.id, number]}\n"
  else
    print "columns = [:account_id, :number]\n"
    print "values = numbers.map{|number| [account.id, number]}\n"
  end
  print "BlockedNumber.import columns, values\n"
  print "\n"
end

desc 'Long running task to test DNS resolution to 3rd party APIs success over time'
task :dns do
  require 'resolv'
  require 'benchmark'

  names = {
    'api.twilio.com' => 'Twilio',
    'api.pusherapp.com' => 'Pusher',
    'impact-prod-db.cjo94dhm4pos.us-east-1.rds.amazonaws.com' => 'RDS'
  }

  domains = {
    'api.twilio.com' => 330,
    'api.pusherapp.com' => 90,
    'impact-prod-db.cjo94dhm4pos.us-east-1.rds.amazonaws.com' => 30
  }

  results = {}
  domains.each do |domain, delay|
    results[domain] = {
      answer: '',
      time: ''
    }
  end

  time_asleep = 0
  960.times do |n|
    domains.each do |domain, delay|
      unless time_asleep % delay == 0
        next
      end
      print "Resolving #{names[domain]}: "
      resolvr = Resolv::DNS.new
      begin
        results[domain][:time] = Benchmark.measure do
          results[domain][:answer] = resolvr.getaddress(domain).to_s
        end
      rescue Resolv::ResolvError => e
        results[domain][:answer] = "#{e.class}: #{e.message}"
      ensure
        # log results
        print "#{results[domain][:answer]}\t"
        print "#{results[domain][:time]}\n"
      end
    end
    resolvr = nil
    sleep(30)
    time_asleep += 30
  end
end
