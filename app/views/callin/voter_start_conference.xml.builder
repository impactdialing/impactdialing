xml.instruct! :xml, :version=>"1.0" 
xml.Response("version"=>"1.0") do |response|
#  xml.Dial("waitUrl"=>"","beep"=>false, "hangupOnStar"=>"false","action"=>"#{APP_URL}/callin/voterleaveConf?session=#{@session.id}&voter=#{@voter.id}") do |d|
  xml.Dial("hangupOnStar"=>"false") do |d|
    d.Conference("session#{@session.id}", "waitUrl"=>"","beep"=>false)
  end
end
@attempt.connecttime=Time.now
@attempt.status = "Connected to caller #{@caller.pin} #{@caller.email}"
@attempt.save
