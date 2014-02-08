namespace :calls do
  desc "Report Calls logged with Twilio that have no record on our system"
  task :list_to, [:to, :start_time, :end_time] => [:environment] do |t, args|
    def p(c)
      print "#{c}\n"
    end
    require 'twilio-ruby'
    # Get your Account Sid and Auth Token from twilio.com/user/account
    numbers     = args[:to].split(':')
    start_time  = args[:start_time]
    end_time    = args[:end_time]
    account_sid = 'AC422d17e57a30598f8120ee67feae29cd'
    auth_token  = '897298ab9f34357f651895a7011e1631'
    client      = Twilio::REST::Client.new account_sid, auth_token
    call_list   = client.accounts.get(account_sid).calls
    call_attrs  = [
      :sid,
      :date_created,
      :to,
      :from,
      :status,
      :duration,
      :answered_by
    ]
    results = {
      'completed'   => [],
      'queued'      => [],
      'ringing'     => [],
      'in-progress' => [],
      'canceled'    => [],
      'failed'      => [],
      'busy'        => [],
      'no-answer'   => []
    }

    l = 0
    results.keys.each{|k| l = k.size > l ? k.size : l}

    numbers.each do |to|
      print "+1#{to}\n"
      results.keys.each do |status|
        opts = {to: to, status: status}
        opts.merge!({'start_time>' => start_time}) if start_time.present?
        opts.merge!({'end_time<' => end_time}) if end_time.present?
        results[status] = call_list.list(opts)
      end

      results.each do |status, calls|
        print "\t#{status}:".ljust(l + 1) + " #{calls.total}\n"
        calls.each do |call|
          print "\t\t#{call.sid}\n"
          print "\t\t\t#{call.start_time} - #{call.end_time}\n"
          print "\t\t\t#{call.duration} - $#{call.price}\n"
        end
      end
      print "==================================================\n"
    end
    print "\n"
  end
end
