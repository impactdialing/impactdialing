namespace :calls do
  require 'twilio-ruby'

  def account_sid
    'AC422d17e57a30598f8120ee67feae29cd'
  end

  def twilio_client
    auth_token  = '897298ab9f34357f651895a7011e1631'
    @client      ||= Twilio::REST::Client.new account_sid, auth_token
  end

  def call_attrs
    [
      :sid,
      :date_created,
      :to,
      :from,
      :status,
      :duration,
      :answered_by
    ]
  end

  def results
    {
      'completed'   => [],
      'queued'      => [],
      'ringing'     => [],
      'in-progress' => [],
      'canceled'    => [],
      'failed'      => [],
      'busy'        => [],
      'no-answer'   => []
    }
  end

  desc "List Twilio Calls to a given number."
  task :list, [:numbers, :direction, :start_time, :end_time] => [:environment] do |t, args|
    numbers     = args[:numbers].split(':')
    direction   = args[:direction]
    start_time  = args[:start_time]
    end_time    = args[:end_time]
    call_list   = twilio_client.accounts.get(account_sid).calls
    report = []
    numbers.each do |number|
        #results.keys.each do |status|
        #opts = {direction => number, 'status' => status}
        opts = {direction => number}
        opts.merge!({'start_time>' => start_time}) if start_time.present?
        opts.merge!({'end_time<' => end_time}) if end_time.present?
        #results[status] = call_list.list(opts)
        #print "Found #{results[status].size} calls, from #{opts}\n"
      #end
      #results.each do |status, calls|
        call_list.list(opts).each do |call|
          summary = []
          summary << call.to
          summary << call.from
          summary << call.status
          summary << call.sid
          summary << call.start_time
          summary << call.end_time
          summary << call.duration
          summary << call.price
          report << summary
        end
      #end
    end
    print "To,From,Status,Calls,SID,Start time,End time,Duration,Price\n"
    print report.map{|row| row.join(',')}.join("\n") + "\n"
  end

  desc "Pull CallerSession call details for given SIDs"
  task :list_client, [:sids] => [:environment] do |t,args|
    sids = args[:sids].split(':')

    print "Fetching data for #{sids.size} sessions.\n"

    header = ['Started', 'Ended', 'Duration']
    report = []

    sids.each do |sid|
      call = twilio_client.accounts.get(account_sid).calls.get(sid)
      report << [
        call.start_time.in_time_zone('Pacific Time (US & Canada)'),
        call.end_time.in_time_zone('Pacific Time (US & Canada)'),
        (call.duration.to_i / 60.0)
      ]
    end

    print header.join(',') + "\n"
    print report.map{|line| line.join(',')}.join("\n") + "\n"
  end
end
