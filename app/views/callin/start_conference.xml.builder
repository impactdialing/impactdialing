xml.instruct! :xml, :version=>"1.0" 
xml.Response("version"=>"1.0") do |response|

  if @publish_channel
    xml.Publish("channel"=>"#{@publish_channel}") {
      xml.Data("name"=>"#{@publish_key}", "value"=>"#{@publish_value}")
    }
  end

 xml.Say("#{@say}") if @say
 xml.Play("#{@play}") if @play
 xml.Dial("hangupOnStar"=>"true","action"=>"#{APP_URL}/callin/leaveConf?session=#{@session.id}&campaign=#{@campaign.id}") do |d|
#    d.Conference("session#{@session.id}", "maxParticipants"=>"2")
#    d.Conference("session#{@session.id}", "endConferenceOnExit"=>"true", "beep"=>"true", "waitUrl"=>"http://twimlets.com/holdmusic?Bucket=com.twilio.music.ambient",  "maxParticipants"=>"2")
#      d.Conference("session#{@session.id}", "endConferenceOnExit"=>"true", "beep"=>"true", "waitUrl"=>"#{APP_URL}/wav/hold.mp3",  "waitMethod"=>"GET", "maxParticipants"=>"2")
      #d.Conference("session#{@session.id}", "endConferenceOnExit"=>"true", "beep"=>"true", "waitUrl"=>"#{APP_URL}/callin/hold",  "waitMethod"=>"GET", "maxParticipants"=>"2")
      d.Conference("session#{@session.id}", "endConferenceOnExit"=>"true", "beep"=>"true", "waitUrl"=>"#{APP_URL}/callin/hold",  "waitMethod"=>"GET")

  end
end

#begin hold time counter
@session.hold_time_start=Time.now
@session.available_for_call=true
@session.save
RAILS_DEFAULT_LOGGER.debug(xml.target!) if DEBUG_TWIML