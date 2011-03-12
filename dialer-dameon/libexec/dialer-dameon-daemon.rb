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
    if DaemonKit.env=="development"
      root_path="/Volumes/MacHD/Users/blevine/dev/impact_dialing/dialer-dameon/"
    else
      root_path="/var/www/html/trunk/dialer-dameon/"
    end


    campaign = Campaign.find(k)
    DaemonKit.logger.info "Working on campaign #{k} #{campaign.name}"
    # avail_campaign_hash = cache_get("avail_campaign_hash") {{}}
    # campaign_hash = avail_campaign_hash[k]
    if campaign.calls_in_progress?
      DaemonKit.logger.info "#{campaign.name} is still dialing, returning"
      return
    end

    if campaign.predective_type=="preview"
      DaemonKit.logger.info "#{campaign.name} is preview dialing, returning"
      return
    end

    stats = campaign.call_stats(10)
    answer_pct = (stats[:answer_pct] * 100).to_i
    callers = CallerSession.find_all_by_campaign_id_and_on_call(k,1)
    callers_on_call = CallerSession.find_all_by_campaign_id_and_on_call_and_available_for_call(k,1,0)
    not_on_call = callers.length - callers_on_call.length
    calls = CallAttempt.find_all_by_campaign_id(k, :conditions=>"call_end is NULL")
    # callers = campaign_hash["callers"]
    # calls = campaign_hash["calls"]
    voters = campaign.voters("not called")
    DaemonKit.logger.info "#{campaign.name}: Callers logged in: #{callers.length}, Callers on call: #{callers_on_call.length}, Callers not on call:  #{not_on_call}, Numbers to call: #{voters.length}, Calls in progress: #{calls.length}, Answer pct: #{answer_pct}"
    
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
      ratio_dial = campaign.predective_type[6,1].to_i
      DaemonKit.logger.info "ratio_dial: #{ratio_dial}, #{callers.length}, #{campaign.predective_type.index("power_")}"
    end
    if campaign.predective_type.index("robo,")!=nil
      ratio_dial = 1
      DaemonKit.logger.info "ratio_dial: #{ratio_dial}, #{callers.length}, #{campaign.predective_type.index("robo")}"
    end

    ratio_dial=campaign.ratio_override if campaign.ratio_override!=nil && !campaign.ratio_override.blank? && campaign.ratio_override > 0

    if answer_pct==0
      ratio_dial=2
    end
    
    
    if (campaign.predective_type=="" || campaign.predective_type.index("power_")==0 || campaign.predective_type.index("robo,")==0)
      #original method
      maxCalls=callers.length * ratio_dial
      DaemonKit.logger.info "maxCalls: #{maxCalls}"
      newCalls=calls.length
      # if campaign.ending_window_method!="Not used"
      #   if campaign.ending_window_method=="Average"
      #     newCalls = newCalls - campaign.calls_in_ending_window(10,"average").length
      #   elsif campaign.ending_window_method=="Longest"
      #     newCalls = newCalls - campaign.calls_in_ending_window(10,"longest").length
      #   end
      # end
      newCalls  = newCalls - maxCalls
    else
      #new mode
      #for each caller on a call
      # bimodal pacing algorithm:
      # when stats[:short_new_call_caller_threshold] callers are on calls of length less than stats[:short_time]s, dial  stats[:dials_needed] lines at stats[:short_new_call_time_threshold]) seconds after the last call began.
      # if a call passes length 15s, dial stats[:dials_needed] lines at stats[:short_new_long_time_threshold]sinto the call.        


      maxCalls=callers.length * stats[:dials_needed]
#      DaemonKit.logger.info "maxCalls: #{maxCalls}"
#      newCalls=calls.length
      newCalls=maxCalls-calls.length
      #newCalls= callers_on_call.length * stats[:dials_needed]
      #for each caller thats not on a call, make stats[:dials_needed] calls
      #newCalls= newCalls  - (not_on_call * stats[:dials_needed]) 
      
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
        DaemonKit.logger.info "short_counter #{short_counter}"
      end
      
      if stats[:ratio_short]>0  && short_counter >0
        max_short=(1/stats[:ratio_short]).round
        short_to_dial = (short_counter/max_short).to_f.ceil
      else
        max_short=0
        short_to_dial=0
      end
      done_short=0
      DaemonKit.logger.info "#{short_to_dial} short_to_dial, #{short_counter} short_counter, ratio short #{stats[:ratio_short]}, max_short: #{max_short}"
      
      callers.each do |session|
        if session.attempt_in_progress.blank?
          pool_size = pool_size + stats[:dials_needed]
          DaemonKit.logger.info "empty to pool, session #{session.id} attempt_in_progress is blank"
          #idle
          #newCalls= newCalls  - stats[:dials_needed]
        else
          attempt = CallAttempt.find(session.attempt_in_progress)
          DaemonKit.logger.info "session #{session.id} attempt_in_progress is #{attempt.id}"
          if attempt.duration!=nil
            if attempt.duration < stats[:short_time] && done_short<short_to_dial
              if attempt.duration > stats[:short_new_call_time_threshold]
                done_short+=1
                #when stats[:short_new_call_caller_threshold] callers are on calls of length less than stats[:short_time]s, dial  stats[:dials_needed] lines at stats[:short_new_call_time_threshold]) seconds after the last call began.
                #newCalls= newCalls  - stats[:dials_needed] 
                pool_size = pool_size + stats[:dials_needed]
                DaemonKit.logger.info "short to pool, duration #{attempt.duration}, done_short=#{done_short}, short_to_dial=#{short_to_dial}"
              end
            else
              # if a call passes length 15s, dial stats[:dials_needed] lines at stats[:short_new_long_time_threshold]sinto the call.        
            #  newCalls= newCalls  - stats[:dials_needed] if attempt.duration > stats[:long_new_call_time_threshold]
              DaemonKit.logger.info "looking at long to pool, session #{session.id}, attempt.duration #{attempt.duration}, thresh #{stats[:long_new_call_time_threshold]}"
              if attempt.duration > stats[:long_new_call_time_threshold]
                DaemonKit.logger.info "LONG TO POOL, session #{session.id}, attempt.duration #{attempt.duration}, thresh #{stats[:long_new_call_time_threshold]}"
                pool_size = pool_size + stats[:dials_needed]
              end
            end
          end
        end
      end

      maxCalls = pool_size
      newCalls = calls.length

      newCalls=0 if newCalls<0
      DaemonKit.logger.info "#{newCalls} newcalls #{maxCalls} maxcalls"
    end

    
    DaemonKit.logger.info "newCalls: #{newCalls}, maxCalls: #{maxCalls}"
      
    if true #(DaemonKit.env=="development" && voters.length>0)  || campaign.id==27 || campaign.id==65 || voters.length > 10
      voter_ids=[]
      voters.each do |voter|
        if newCalls.to_i < maxCalls.to_i
          voter_ids<<voter
          newCalls+=1
        end
      end
    end
    
    if voter_ids.length >10  || campaign.id==27
      #spawn externally
      voter_id_list=voter_ids.collect{|v| v.id}.join(",")
      if voter_id_list.strip!=""
        campaign.calls_in_progress=true
        campaign.save
        DaemonKit.logger.info "Spawning external dialer for #{campaign.name} #{voter_id_list}"
        exec("ruby #{root_path}/place_campaign_calls.rb #{DaemonKit.env} #{voter_id_list}") if fork == nil
      end
    else
      voter_ids.each do |voter|
        DaemonKit.logger.info "calling #{voter.Phone} #{campaign.name}"
        callNewVoter(voter,campaign)
      end
      # voters.each do |voter|
      #   if newCalls.to_i < maxCalls.to_i
      #     DaemonKit.logger.info "#{newCalls.to_i} newcalls < #{maxCalls.to_i} maxcalls, calling #{voter.Phone}"
      #     newCalls+=1
      #     callNewVoter(voter,campaign)
      #   end
      # end
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
    load_test=false
    logged_in_campaigns.each do |c|
      load_test=true if c[0]=="38"
    end
    logged_in_campaigns.data_seek(0)
    
#    load_test=logged_in_campaigns.collect{|l| l.id}.index(38)
    
    if Time.now.hour > 0 && Time.now.hour < 6 && DaemonKit.env!="development" && load_test==false # ends 10pm PST starts 6am eastern
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

    sleep 3
#    puts "ActiveRecord::Base.verify_active_connections!: " + ActiveRecord::Base.verify_active_connections!.inspect
  rescue Exception => e
    DaemonKit.logger.info "Rescued - #{ e } (#{ e.class })!"
    DaemonKit.logger.info e.backtrace
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