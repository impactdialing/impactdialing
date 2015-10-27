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
    report      = []
    opts        = {
      page_size: 1000
    }
    opts.merge!({'start_time>' => start_time}) if start_time.present?
    opts.merge!({'end_time<' => end_time}) if end_time.present?

    print "To,From,Status,Calls,SID,Start time,End time,Duration,Price\n"
    summarize = Proc.new{|opts| 
      calls = call_list.list(opts)
      while calls.any?
        calls.each do |call|
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
        print report.map{|row| row.join(',')}.join("\n") + "\n"
        calls = calls.next_page
        report = []
      end
    }
    if numbers.empty?
      summarize.call(opts)
    else
      numbers.each do |number|
        opts.merge!({direction => number}) if direction.present? and number.present?
        summarize.call(opts)
      end
    end
  end

  desc "Search Twilio Call Log for Recycle Rate Violators"
  task :list_recycle_violations, [:from, :start_time, :end_time] => [:environment] do |t,args|
    from       = args[:from]
    start_time = args[:start_time]
    end_time   = args[:end_time]
    call_list  = twilio_client.accounts.get(account_sid).calls
    opts       = {
      page_size: 1000,
      status: 'completed'
    }
    opts.merge!({'from' => from}) if from.present?
    opts.merge!({'start_time>' => start_time}) if start_time.present?
    opts.merge!({'end_time<' => end_time}) if end_time.present?

    phones = {}
    violators = {}


    collect_violators = Proc.new{|call|
      phone = call.to
      time  = Time.parse(call.start_time)
      phones[phone] ||= []
      phones[phone] << time

      if phones[phone].size > 1 and phones[phone].any?{|t| (time - t).abs < 1.hour and time != t}
        violators[phone] ||= []
        violators[phone] << [
          call.from,
          call.sid,
          call.status,
          call.start_time,
          call.end_time
        ]
      end
    }
    a = b = 0
    a += 1
    calls = call_list.list(opts)
    ph    = '+14849248071'

    while calls.any?
      b += calls.size
      p "#{a}-#{b}"
      a += calls.size
      calls.each do |call|
        collect_violators.call(call)
      end
      p "- #{violators.keys.size} violators" if violators.keys.size > 0
      calls = calls.next_page
    end

    #byebug if phones[ph].present?
    print "To,# of Violations,From,SID,Status,Start,End\n"
    violators.each do |phone, violations|
      print "#{phone},#{violations.size},#{violations.first.join(",")}\n"
    end
    print "\n"
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
