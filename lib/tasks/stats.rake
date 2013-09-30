desc "Run Admin Report"
task :admin_report, [:start_date, :end_date] => [:environment] do |t, args|
  require 'reports'

  start_date = Time.zone.parse(args[:start_date]).utc.beginning_of_day
  end_date = Time.zone.parse(args[:end_date]).utc.end_of_day

  billable_minutes = Reports::BillableMinutes.new(start_date, end_date)
  report = Reports::Admin::EnterpriseByAccount.new(billable_minutes)
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

desc "Report Calls logged with Twilio that have no record on our system"
task :diff_twilio_sids => [:environment] do
  require 'twilio-ruby'
  # Get your Account Sid and Auth Token from twilio.com/user/account
  account_sid = 'AC422d17e57a30598f8120ee67feae29cd'
  auth_token = '897298ab9f34357f651895a7011e1631'
  @client = Twilio::REST::Client.new account_sid, auth_token

  def load_record(call)
    record = CallerSession.where(sid: call.sid)
    return record if record.count > 0
    record = TransferAttempt.where(sid: call.sid)
    return record if record.count > 0
    record = CallAttempt.where(sid: call.sid)
    return record if record.count > 0
    return nil
  end

  def record_exists?(call)
    return load_record(call).present?
  end

  def record_duration_matches?(call, record)
    return record.tDuration.to_i == call.duration.to_i
  end

  missing_records = []
  duration_mismatches = []

  start_date = "2013-08-01"
  end_date = "2013-08-04"
  list_options = {
    :"start_time>" => start_date,
    :"start_time<" => end_date
  }

  all_twilio_calls = @client.account.calls.list(list_options.merge({
    page_size: 1
  }))

  total_calls = all_twilio_calls.total
  per_page = 500
  total_pages = (total_calls/per_page.to_f).ceil

  print "Found #{total_calls} Twilio calls between #{start_date} and #{end_date}...\n"

  twilio_total = 0
  record_total = 0
  1.times do |page_no|
    twilio_calls = @client.account.calls.list(list_options.merge({
      page: page_no,
      page_size: per_page
    }))

    twilio_calls.each do |call|
      print "\tTwilio:\t#{call.duration}\t#{call.from}\t#{call.direction}\t$#{call.price}\n"
      twilio_total += (call.duration.to_i/60.0).ceil
      record = load_record(call)
      unless record.present?
        missing_records << call
        print "\tMissing Record\n"
      end
      unless record.nil?
        record = record.first

        record_total += (record.tDuration.to_i/60.0).ceil
        unless record_duration_matches?(call, record)
          print "\tDuration Mismatch:\t#{record.tDuration}$#{record.tPrice}\n"
          duration_mismatches << [call, record]
        end
      end
    end
    print "Missing records: #{missing_records.size}\n"
    print "Duration Mismatches: #{duration_mismatches.size}\n"

    if duration_mismatches.size > 0
      print "Record\t\tTwilio\t\tDiff\n"

      duration_mismatches.each do |dm|
        call = dm.first
        record = dm.last
        print "#{(record.tDuration || 0)}\t\t#{call.duration}\t\t#{(record.tDuration || 0) - call.duration.to_i}\n"
      end
    end

    print "\nTotals\n"
    print "Twilio:\t#{twilio_total}\n"
    print "Record:\t#{record_total}\n"
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