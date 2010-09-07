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
    calls = CallAttempt.find_all_by_campaign_id(k, :conditions=>"call_end is NULL")
    # callers = campaign_hash["callers"]
    # calls = campaign_hash["calls"]
    voters = campaign.voters("not called")
    DaemonKit.logger.info "Callers logged in: #{callers.length}, Voters to call: #{voters.length}, Calls in progress: #{calls.length}, Answer pct: #{answer_pct}"
    
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
    
    maxCalls=callers.length * ratio_dial
    newCalls=calls.length
    
    #predecitve
    if campaign.ending_window_method!="Not used"
      if campaign.ending_window_method=="Average"
        newCalls = newCalls - campaign.calls_in_ending_window(10,"average").length
      elsif campaign.ending_window_method=="Longest"
        newCalls = newCalls - campaign.calls_in_ending_window(10,"longest").length
      end
    end
    newCalls=0 if newCalls<0
    
    voters.each do |voter|
      #do we need to make another call?
      if newCalls < maxCalls
        DaemonKit.logger.info "#{newCalls} newcalls < #{maxCalls} maxcalls, calling #{voter.Phone}"
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
loop do
  begin
    # @avail_campaign_hash = cache_get("avail_campaign_hash") {{}}
    # DaemonKit.logger.info "avail_campaign_hash: #{@avail_campaign_hash.keys}"
    logged_in_campaigns = ActiveRecord::Base.connection.execute("select distinct campaign_id from caller_sessions where on_call=1")
    DaemonKit.logger.info "logged_in_campaigns: #{logged_in_campaigns.num_rows}"

    if logged_in_campaigns.num_rows>0
      logged_in_campaigns.each do |k|
        handleCampaign(k[0])
      end
    else
      #cleanup
      if rand(10)==2
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