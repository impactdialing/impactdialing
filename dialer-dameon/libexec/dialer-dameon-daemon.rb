#avail_callers_hash
#Hash of CallerSessions in progress

# Change this file to be a wrapper around your daemon code.

# Do your post daemonization configuration here
# At minimum you need just the first line (without the block), or a lot
# of strange things might start happening...
DaemonKit::Application.running! do |config|
  # Trap signals with blocks or procs
  # config.trap( 'INT' ) do
  #   # do something clever
  # end
  config.trap( 'INT', Proc.new { exit! } )

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
  



  def handleCampaign(k)
    DaemonKit.logger.info "Working on campaign #{k}"
    # avail_campaign_hash = cache_get("avail_campaign_hash") {{}}
    # campaign_hash = avail_campaign_hash[k]
    campaign = Campaign.find(k)
    stats = campaign.call_stats(10)
    answer_pct = (stats[:answer_pct] * 100).to_i
    callers = CallerSession.find_all_by_campaign_id_and_on_call(k,1)
    callers_on_call = CallerSession.find_all_by_campaign_id_and_on_call_and_available_for_call(k,1,0)
    not_on_call = callers.length - callers_on_call.length
    calls = CallAttempt.find_all_by_campaign_id(k, :conditions=>"call_end is NULL")
    # callers = campaign_hash["callers"]
    # calls = campaign_hash["calls"]
    voters = campaign.voters("not called")
    DaemonKit.logger.info "Callers logged in: #{callers.length}, Callers on call: #{callers_on_call.length}, Callers not on call:  #{not_on_call}, Voters to call: #{voters.length}, Calls in progress: #{calls.length}, Answer pct: #{answer_pct}"
    
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

    ratio_dial=campaign.ratio_override if campaign.ratio_override!=nil && !campaign.ratio_override.blank? && campaign.ratio_override > 0

    if answer_pct==0
      ratio_dial=2
    end
    
    
    if campaign.predective_type==""
      #original method
      maxCalls=callers.length * ratio_dial
      newCalls=calls.length
      if campaign.ending_window_method!="Not used"
        if campaign.ending_window_method=="Average"
          newCalls = newCalls - campaign.calls_in_ending_window(10,"average").length
        elsif campaign.ending_window_method=="Longest"
          newCalls = newCalls - campaign.calls_in_ending_window(10,"longest").length
        end
      end
    else
      maxCalls=callers.length * stats[:dials_needed]
#      newCalls=calls.length
      newCalls=calls.length
      #for each caller thats not on a call, make stats[:dials_needed] calls
      newCalls= newCalls  - (not_on_call * stats[:dials_needed]) 
      #for each caller on a call
      # bimodal pacing algorithm:
      # when stats[:short_new_call_caller_threshold] callers are on calls of length less than stats[:short_time]s, dial  stats[:dials_needed] lines at stats[:short_new_call_time_threshold]) seconds after the last call began.
      # if a call passes length 15s, dial stats[:dials_needed] lines at stats[:short_new_long_time_threshold]sinto the call.        
      
      short_counter=0
      callers_on_call.each do |session|
         if !session.attempt_in_progress.blank?
           attempt = CallAttempt.find(session.attempt_in_progress)
           if attempt.duration!=nil && attempt.duration < stats[:short_time]
             short_counter+=1
           end
         end
      end
      DaemonKit.logger.info "short_counter #{short_counter}"
      
      if stats[:ratio_short]>0  && short_counter >0 && !stats[:ratio_short].infinite? 
        max_short=(1/stats[:ratio_short]).round
        short_to_dial = (short_counter/max_short).to_f.ceil
      else
        max_short=0
        short_to_dial=0
      end
      done_short=0
      DaemonKit.logger.info "#{short_to_dial} short_to_dial, #{short_counter} short_counter, ratio short #{stats[:ratio_short]}, max_short: #{max_short}"
      
      callers_on_call.each do |session|
        if session.attempt_in_progress.blank?
          #hmm just finished?  better dial out
          newCalls= newCalls  - stats[:dials_needed]
        else
          attempt = CallAttempt.find(session.attempt_in_progress)
          if attempt.duration!=nil
            if attempt.duration < stats[:short_time] && done_short<short_to_dial
              if attempt.duration > stats[:short_new_call_time_threshold]
                done_short+=1
                #when stats[:short_new_call_caller_threshold] callers are on calls of length less than stats[:short_time]s, dial  stats[:dials_needed] lines at stats[:short_new_call_time_threshold]) seconds after the last call began.
                newCalls= newCalls  - stats[:dials_needed] 
                DaemonKit.logger.info "Dialed a short, done_short=#{done_short}, short_to_dial=#{short_to_dial}"
              end
            else
              # if a call passes length 15s, dial stats[:dials_needed] lines at stats[:short_new_long_time_threshold]sinto the call.        
              newCalls= newCalls  - stats[:dials_needed] if attempt.duration > stats[:long_new_call_time_threshold]
            end
          end
        end
      end

    end

    newCalls=0 if newCalls<0
    DaemonKit.logger.info "#{newCalls} newcalls #{maxCalls} maxcalls"
    
    voters.each do |voter|
      #do we need to make another call?
      if newCalls.to_i < maxCalls.to_i
        DaemonKit.logger.info "#{newCalls.to_i} newcalls < #{maxCalls.to_i} maxcalls, calling #{voter.Phone}"
        newCalls+=1
        callNewVoter(voter,campaign)
      end
    end

  #      voterTest = Voter.find_by_campaign_id(callSession.campaign_id, :conditions=>"status='Call attempt in progress' and active=1")

  end

  def callNewVoter(voter,campaign)
    DaemonKit.logger.info "calling: #{voter.Phone}"
    voter.status='Call attempt in progress'
    voter.save
    d = Dialer.startcall(voter, campaign)
  end
  
end


# todo - remove all callers in progress
# delete cache for now
#cache_delete("avail_campaign_hash")
#ActiveRecord::Base.connection.execute("update caller_sessions set available_for_call=0")

#ActiveRecord::Base.connection.execute("update voters set status='not called'")

#here be the main loop
DaemonKit.logger.info "Starting up..."
doInitialClean=true
loop do
  begin
    # @avail_campaign_hash = cache_get("avail_campaign_hash") {{}}
    # DaemonKit.logger.info "avail_campaign_hash: #{@avail_campaign_hash.keys}"
    logged_in_campaigns = ActiveRecord::Base.connection.execute("select distinct campaign_id from caller_sessions where on_call=1")
    DaemonKit.logger.info "logged_in_campaigns: #{logged_in_campaigns.num_rows}"
    
    if Time.now.hour < 7 && DaemonKit.env!="development" # ends 10pm EST 
      # too late, clear all logged in callers
      DaemonKit.logger.info "Off hours, don't make any calls"
      ActiveRecord::Base.connection.execute("update caller_sessions set on_call=0")      
    elsif logged_in_campaigns.num_rows>0
      logged_in_campaigns.each do |k|
        handleCampaign(k[0])
      end
    else
      #cleanup
      if rand(10)==2 || doInitialClean
        doInitialClean=false        
        logged_out_campaigns = ActiveRecord::Base.connection.execute("select distinct campaign_id from caller_sessions where campaign_id not in (select distinct campaign_id from caller_sessions where on_call=1) and campaign_id is not null")
        logged_out_campaigns.each do |k|
          DaemonKit.logger.info "Cleaning up campaign #{k[0]}"
          in_progress = Campaign.find(k[0]).end_all_calls(Dialer.account, Dialer.auth, Dialer.appurl) 
        end
      end
    end

    sleep 5
#    puts "ActiveRecord::Base.verify_active_connections!: " + ActiveRecord::Base.verify_active_connections!.inspect
  rescue Exception => e
    DaemonKit.logger.info "Rescued - #{ e } (#{ e.class })!"
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