namespace :reports do
  desc "Report account-wide dials"
  task :account_dials, [:account_ids,:start_date] => :environment do |t, args|
    account_ids = args[:account_ids].split(',').compact
    year, month, day = args[:start_date].split('/')
    start_time  = Time.new(year, month, day, 0, 0, 0)

    headers = ['Dials', 'Call status']
    reports = []

    account_ids.each do |account_id|
      campaign_ids = Campaign.where(account_id: account_id).pluck(:id)
      dials        = CallAttempt.where('created_at >= ?', start_time).where(campaign_id: campaign_ids).group(:status).count
      total        = dials.values.sum
      data         = dials.values.zip(dials.keys) + [[total, 'Total']]
      reports      << data.map{|tuple| tuple.join(',')}
    end

    reports.each_with_index do |report, index|
      print "Account #{account_ids[index]} #{start_time.strftime('%b %d, %Y')} - #{Time.now.strftime('%b %d, %Y')}\n"
      print headers.join(',') + "\n"
      print report.join("\n") + "\n"
    end
  end
end
