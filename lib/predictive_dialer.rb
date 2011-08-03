require File.join(RAILS_ROOT, 'config/environment')

logger = Logger.new(Rails.root.join("log", "predictive_dialer_#{RAILS_ENV}.log"))
ActiveRecord::Base.logger = logger

#avail_callers_hash
#Hash of CallerSessions in progress

# Change this file to be a wrapper around your daemon code.

# Do your post daemonization configuration here
# At minimum you need just the first line (without the block), or a lot
# of strange things might start happening...
Signal.trap('INT', Proc.new { exit! })

private
def cache_get(key)
  unless output = CACHE.get(key)
    output = yield
    CACHE.set(key, output)
  end
  return output
end

def cache_delete(key)
  CACHE.delete(key)
end

def cache_set(key)
  output = yield
  if CACHE.get(key)==nil
    CACHE.add(key, output)
  else
    CACHE.set(key, output)
  end
end


def handle_campaign(k)
  root_path = File.join(File.dirname(__FILE__, '..'))

  campaign = Campaign.find(k)
  Rails.logger.info "Working on campaign #{k} #{campaign.name}"
  if campaign.calls_in_progress?
    Rails.logger.info "#{campaign.name} is still dialing, returning"
    return
  end

  if campaign.predective_type=="preview"
    Rails.logger.info "#{campaign.name} is preview dialing, returning"
    return
  end

  stats = campaign.call_stats(10)
  answer_pct = (stats[:answer_pct] * 100).to_i
  callers = CallerSession.find_all_by_campaign_id_and_on_call(k, 1)
  callers_on_call = CallerSession.find_all_by_campaign_id_and_on_call_and_available_for_call(k, 1, 0)
  not_on_call = callers.length - callers_on_call.length
  calls = CallAttempt.find_all_by_campaign_id(k, :conditions=>"call_end is NULL")
  voters = campaign.voters("not called")
  Rails.logger.info "#{campaign.name}: Callers logged in: #{callers.length}, Callers on call: #{callers_on_call.length}, Callers not on call:  #{not_on_call}, Numbers to call: #{voters.length}, Calls in progress: #{calls.length}, Answer pct: #{answer_pct}"

  if callers.length==0
    in_progress = campaign.end_all_calls(Dialer.account, Dialer.auth, Dialer.appurl)
    in_progress.each do |attempt|
    end
  end

  if answer_pct <= campaign.ratio_4
    ratio_dial=4
  elsif answer_pct <= campaign.ratio_3
    ratio_dial=3
  elsif answer_pct <= campaign.ratio_2
    ratio_dial=2
  else
    ratio_dial=1
  end

  if campaign.predective_type.index("power_")!=nil
    ratio_dial = campaign.predective_type[6, 1].to_i
    Rails.logger.info "ratio_dial: #{ratio_dial}, #{callers.length}, #{campaign.predective_type.index("power_")}"
  end
  if campaign.predective_type.index("robo,")!=nil
    ratio_dial = 5
    Rails.logger.info "ratio_dial: #{ratio_dial}, #{callers.length}, #{campaign.predective_type.index("robo")}"
  end

  ratio_dial=campaign.ratio_override if campaign.ratio_override!=nil && !campaign.ratio_override.blank? && campaign.ratio_override > 0

  if answer_pct==0
    ratio_dial=2
  end


  if (campaign.predective_type=="" || campaign.predective_type.index("power_")==0 || campaign.predective_type.index("robo,")==0)
    #original method
    max_calls=callers.length * ratio_dial
    Rails.logger.info "max_calls: #{max_calls}"
    new_calls=calls.length
    new_calls = new_calls - max_calls
  else
    #new mode
    #for each caller on a call
    # bimodal pacing algorithm:
    # when stats[:short_new_call_caller_threshold] callers are on calls of length less than stats[:short_time]s, dial  stats[:dials_needed] lines at stats[:short_new_call_time_threshold]) seconds after the last call began.
    # if a call passes length 15s, dial stats[:dials_needed] lines at stats[:short_new_long_time_threshold]sinto the call.


    max_calls=callers.length * stats[:dials_needed]
    new_calls=max_calls-calls.length

    pool_size=0

    short_counter=0
    if campaign.predective_type=="algorithm1"
      callers_on_call.each do |session|
        if !session.attempt_in_progress.blank?
          attempt = CallAttempt.find(session.attempt_in_progress)
          if attempt.duration!=nil && attempt.duration < stats[:short_time]
            short_counter+=1
          end
        end
      end
      Rails.logger.info "short_counter #{short_counter}"
    end

    if stats[:ratio_short]>0 && short_counter > 0
      max_short=(1/stats[:ratio_short]).round
      short_to_dial = (short_counter/max_short).to_f.ceil
    else
      max_short=0
      short_to_dial=0
    end
    done_short=0
    Rails.logger.info "#{short_to_dial} short_to_dial, #{short_counter} short_counter, ratio short #{stats[:ratio_short]}, max_short: #{max_short}"

    callers.each do |session|
      if session.attempt_in_progress.blank?
        pool_size = pool_size + stats[:dials_needed]
        Rails.logger.info "empty to pool, session #{session.id} attempt_in_progress is blank"
        #idle
      else
        attempt = CallAttempt.find(session.attempt_in_progress)
        Rails.logger.info "session #{session.id} attempt_in_progress is #{attempt.id}"
        if attempt.duration!=nil
          if attempt.duration < stats[:short_time] && done_short<short_to_dial
            if attempt.duration > stats[:short_new_call_time_threshold]
              done_short+=1
              #when stats[:short_new_call_caller_threshold] callers are on calls of length less than stats[:short_time]s, dial  stats[:dials_needed] lines at stats[:short_new_call_time_threshold]) seconds after the last call began.
              pool_size = pool_size + stats[:dials_needed]
              Rails.logger.info "short to pool, duration #{attempt.duration}, done_short=#{done_short}, short_to_dial=#{short_to_dial}"
            end
          else
            # if a call passes length 15s, dial stats[:dials_needed] lines at stats[:short_new_long_time_threshold]sinto the call.
            Rails.logger.info "looking at long to pool, session #{session.id}, attempt.duration #{attempt.duration}, thresh #{stats[:long_new_call_time_threshold]}"
            if attempt.duration > stats[:long_new_call_time_threshold]
              Rails.logger.info "LONG TO POOL, session #{session.id}, attempt.duration #{attempt.duration}, thresh #{stats[:long_new_call_time_threshold]}"
              pool_size = pool_size + stats[:dials_needed]
            end
          end
        end
      end
    end

    max_calls = pool_size
    new_calls = calls.length

    new_calls=0 if new_calls<0
    Rails.logger.info "#{new_calls} newcalls #{max_calls} maxcalls"
  end


  Rails.logger.info "new_calls: #{new_calls}, max_calls: #{max_calls}"

  voter_ids = campaign.voters.scheduled.limit(max_calls - new_calls)
  new_calls = new_calls + voter_ids.size
  voters.each do |voter|
    break if new_calls.to_i >= max_calls.to_i
    unless voter_ids.include?(voter)
      voter_ids << voter
      new_calls+=1
    end
  end

  if voter_ids.length >10 || campaign.id==27
    #spawn externally
    voter_id_list=voter_ids.collect { |v| v.id }.join(",")
    if voter_id_list.strip!=""
      campaign.calls_in_progress=true
      campaign.save
      Rails.logger.info "Spawning external dialer for #{campaign.name} #{voter_id_list}"
      exec("ruby #{root_path}/lib/place_campaign_calls.rb #{Rails.env} #{voter_id_list}") if fork == nil
    end
  else
    voter_ids.each do |voter|
      Rails.logger.info "calling #{voter.Phone} #{campaign.name}"
      call_new_voter(voter, campaign)
    end
  end

end

def call_new_voter(voter, campaign)
  Rails.logger.info "calling: #{voter.Phone}"
  voter.status='Call attempt in progress'
  voter.save
  d = Dialer.startcall(voter, campaign)
end


# need to do - remove all callers in progress
# delete cache for now
#cache_delete("avail_campaign_hash")
#ActiveRecord::Base.connection.execute("update caller_sessions set available_for_call=0")

#ActiveRecord::Base.connection.execute("update voters set status='not called'")

#here be the main loop
Rails.logger.info "Starting up..."
do_initial_clean=true
loop do
  begin
    logged_in_campaigns = ActiveRecord::Base.connection.execute("select distinct campaign_id from caller_sessions where on_call=1")
    Rails.logger.info "logged_in_campaigns: #{logged_in_campaigns.num_rows}"
    load_test=false
    logged_in_campaigns.each do |c|
      load_test=true if c[0]=="38"
    end
    logged_in_campaigns.data_seek(0)

    if Time.now.hour > 0 && Time.now.hour < 6 && Rails.env!="development" && load_test==false # ends 10pm PST starts 6am eastern
      Rails.logger.info "Off hours, don't make any calls"
      ActiveRecord::Base.connection.execute("update caller_sessions set on_call=0")
    elsif logged_in_campaigns.num_rows>0
      logged_in_campaigns.each do |k|
        handle_campaign(k[0])
      end
    else
      #cleanup
      if rand(10)==2 || do_initial_clean
        do_initial_clean=false
        logged_out_campaigns = ActiveRecord::Base.connection.execute("select distinct campaign_id from caller_sessions where campaign_id not in (select distinct campaign_id from caller_sessions where on_call=1) and campaign_id is not null")
        logged_out_campaigns.each do |k|
          Rails.logger.info "Cleaning up campaign #{k[0]}"
          in_progress = Campaign.find(k[0]).end_all_calls(Dialer.account, Dialer.auth, Dialer.appurl)
        end
      end
    end

    sleep 3
  rescue Exception => e
    Rails.logger.info "Rescued - #{ e } (#{ e.class })!"
    Rails.logger.info e.backtrace
    ActiveRecord::Base.connection.reconnect!
  end
end

#http://blog.elctech.com/2009/10/06/ruby-daemons-and-angels/
#
# proportion of call attempts that are answered
# duration of time to answer
# duration of service
# number of call attempt at once
#
# avail servers - (set time remain <= set time to call party, or idle)
# attempts in progress - add if above
#
# 2 lines at once in answering under 33 %
# 3 lines at once if answering under 20%
#
#
# how many times to call a non answer back and do we delay?

