desc "rescue wayward calls" 

task :post_call_availabilty_check => :environment do
  # put caller sessions that have been off their last call for more than 90 seconds back into the queue
  #include Twilio
  #require 'active_record'
  
  sql="select cs.id, UTC_TIMESTAMP()-ca.call_end as seconds_since_last_attempt_ended, c.name, ca.call_end, attempt_in_progress, cs.campaign_id from caller_sessions cs
  join call_attempts ca on ca.id=cs.attempt_in_progress
  join campaigns c on c.id=cs.campaign_id
   where on_call=1 and available_for_call=0 and UTC_TIMESTAMP()-ca.call_end > 45 and ca.status <> 'Call in progress'"
   
  @session_to_fix= ActiveRecord::Base.connection.execute(sql)
  @session_to_fix.each do |s|
    puts s.inspect
    @session=CallerSession.find( s[0])
#    puts @session.inspect
    debug="Session #{@session.id} CallAttempt #{@session.attempt_in_progress} Campaign #{s[2]} Idle #{s[1].to_i}s"
    u = Uakari.new("011c309139adae5ea68dac0b8020fcb5-us2")
    u.send_email({
        :track_opens => true, 
        :track_clicks => true, 
        :message => {
            :subject => "Idle session fix", 
            :html => debug, 
            :text => debug, 
            :from_name => 'Impact Dialing', 
            :from_email => 'email@impactdialing.com', 
            :to_email=>['michael@impactdialing.com','brian@impactdialing.com']
        }
    })
    @session.available_for_call=1
    @session.save
    t = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    a=t.call("POST", "Calls/#{@session.sid}", {'CurrentUrl'=>"#{APP_URL}/callin/start_conference?session=#{@session.id}&campaign=#{@session.campaign_id}"})

    require 'pusher'
    Pusher.app_id = PUSHER_APP_ID
    Pusher.key = PUSHER_KEY
    Pusher.secret = PUSHER_SECRET

    if @session.campaign.type=="preview"
      Pusher[@session.session_key].trigger('waiting', 'preview')
    else
      Pusher[@session.session_key].trigger('waiting', 'ok')
    end


  end

end
