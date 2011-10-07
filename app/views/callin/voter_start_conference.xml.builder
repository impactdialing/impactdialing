xml.instruct! :xml, :version=>"1.0" 
xml.Response("version"=>"1.0") do |response|
#  xml.Dial("waitUrl"=>"","beep"=>false, "hangupOnStar"=>"false","action"=>"#{APP_URL}/callin/voterleaveConf?session=#{@session.id}&voter=#{@voter.id}") do |d|

  if @publish_channel
    xml.Publish("channel"=>"#{@publish_channel}") {
      xml.Data("name"=>"#{@publish_key}", "value"=>"#{@publish_value}")
    }
  end

  xml.Dial("record"=>"true", "hangupOnStar"=>"false") do |d|
    d.Conference("session#{@available_caller_session.id}", "waitUrl"=>"","beep"=>false, "endConferenceOnExit"=>"true", "maxParticipants"=>"2")
  end
end
@attempt.connecttime=Time.now
@attempt.status = "Connected to caller #{@available_caller_session.caller.pin} #{@available_caller_session.caller.email}"
@attempt.save
RAILS_DEFAULT_LOGGER.debug(xml.target!) if DEBUG_TWIML
