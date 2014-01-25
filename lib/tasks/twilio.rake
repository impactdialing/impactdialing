namespace :calls do
  desc "Report Calls logged with Twilio that have no record on our system"
  task :list_to, [:to] => [:environment] do |t, args|
    def p(c)
      print "#{c}\n"
    end
    require 'twilio-ruby'
    # Get your Account Sid and Auth Token from twilio.com/user/account
    to          = args[:to]
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

    results.keys.each do |status|
      results[status] = call_list.list(to: to, status: status)
    end

    results.each do |status, calls|
      p "#{status}:".ljust(l + 1) + " #{calls.total}"
    end
    print "\n"
  end
end
