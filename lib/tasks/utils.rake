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
