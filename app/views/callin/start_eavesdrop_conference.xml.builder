xml.instruct! :xml, :version=>"1.0" 
xml.Response("version"=>"1.0") do |response|

 xml.Dial("hangupOnStar"=>"true") do |d|
#    d.Conference("session#{@session.id}", "maxParticipants"=>"2")
#    d.Conference("session#{@session.id}", "endConferenceOnExit"=>"true", "beep"=>"true", "waitUrl"=>"http://twimlets.com/holdmusic?Bucket=com.twilio.music.ambient",  "maxParticipants"=>"2")
#      d.Conference("session#{@session.id}", "endConferenceOnExit"=>"true", "beep"=>"true", "waitUrl"=>"#{APP_URL}/wav/hold.mp3",  "waitMethod"=>"GET", "maxParticipants"=>"2")
    d.Conference("session#{params[:session]}", "endConferenceOnExit"=>"false", "beep"=>"false", "waitUrl"=>"#{APP_URL}/callin/hold",  "waitMethod"=>"GET","muted"=>"#{@muted}")

  end
end

