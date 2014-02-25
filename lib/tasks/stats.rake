desc "Run Admin Report"
task :admin_report, [:start_date, :end_date, :type] => [:environment] do |t, args|
  require 'reports'

  start_date = Time.zone.parse(args[:start_date]).utc.beginning_of_day
  end_date = Time.zone.parse(args[:end_date]).utc.end_of_day
  type = args[:type] || 'All'

  billable_minutes = Reports::BillableMinutes.new(start_date, end_date)
  if type == 'All'
    p 'running all by account'
    report = Reports::Admin::AllByAccount.new(billable_minutes)
  else
    report = Reports::Admin::EnterpriseByAccount.new(billable_minutes)
  end
  print report.build
  print "\n"
end

desc "Perform Admin Report Job"
task :admin_report_job, [:start_date, :end_date] => [:environment] do |t, args|
  start_date = args[:start_date]
  end_date = args[:end_date]

  report = AdminReportJob.perform(start_date, end_date)
  print report
  print "\n"
end

desc "Run ClientByCaller Report"
task :client_by_caller_report, [:start_date, :end_date, :account_id] => [:environment] do |t, args|
  require 'reports'

  start_date = Time.zone.parse(args[:start_date]).utc.beginning_of_day
  end_date = Time.zone.parse(args[:end_date]).utc.end_of_day
  account_id = args[:account_id]

  if account_id.to_i > 0
    accounts = [Account.find(account_id)]
  else
    accounts = Account.all
  end
  billable_minutes = Reports::BillableMinutes.new(start_date, end_date)
  accounts.each do |account|
    report = Reports::Customer::ByCaller.new(billable_minutes, account)
    output = report.build
    unless output.empty?
      print "Account##{account.id}\n"
      print output
      print "\n"
      account_total = output.values.inject(0){ |s,n| s + n.to_i }
      print "Account total:\t#{account_total}\n"
    end
  end
end

desc "Run ClientByCampaign Report"
task :client_by_campaign_report, [:start_date, :end_date, :account_id] => [:environment] do |t, args|
  require 'reports'

  start_date = Time.zone.parse(args[:start_date]).utc.beginning_of_day
  end_date = Time.zone.parse(args[:end_date]).utc.end_of_day
  account_id = args[:account_id]

  if account_id.to_i > 0
    accounts = [Account.find(account_id)]
  else
    accounts = Account.all
  end
  accounts.each do |account|
    billable_minutes = Reports::BillableMinutes.new(start_date, end_date)
    report = Reports::Customer::ByCampaign.new(billable_minutes, account)
    output = report.build
    unless output.empty?
      print "Account##{account.id}"
      print output
      print "\n"
      account_total = output.values.inject(0){ |s,n| s + n.to_i }
      print "Account total:\t#{account_total}\n"
    end
  end
end

desc 'Kill off phantom callers'
task :destory_phantoms => :environment do
  # find calls with Twilio shows as ended but are still logged into our system
  phatom_callers = CallerSession.all(:conditions=>"on_call = 1 and tDuration is not NULL")
  phatom_callers.each do |phantom|
    phantom.end_running_call
    phantom.on_call=0
    phantom.save
    message="killed Phantom #{phantom.id} (#{phantom.campaign.name})"
    puts message
    Postoffice.deliver_feedback(message)
  end
end