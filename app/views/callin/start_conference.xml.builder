xml.instruct! :xml, :version=>"1.0" 
xml.Response("version"=>"1.0") do |response|
  xml.Dial("hangupOnStar"=>"true","action"=>"#{APP_URL}/callin/leaveConf?session=#{@session.id}&campaign=#{@campaign.id}") do |d|
#    d.Conference("session#{@session.id}", "maxParticipants"=>"2")
    d.Conference("session#{@session.id}", "beep"=>"true", "waitUrl"=>"http://twimlets.com/holdmusic?Bucket=com.twilio.music.ambient")
  end
end

#begin hold time counter
@session.hold_time_start=Time.now
@session.save