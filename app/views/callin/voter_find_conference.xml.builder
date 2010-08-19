xml.instruct! :xml, :version=>"1.0" 
xml.Response("version"=>"1.0") do |response|
  xml.Dial("hangupOnStar"=>"false","action"=>"#{APP_URL}/callin/voterleaveConf?session=#{@session.id}&voter=#{@voter.id}") do |d|
    d.Conference("session#{@session.id}")
  end
end
