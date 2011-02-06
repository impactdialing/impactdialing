xml.instruct! :xml, :version=>"1.0" 
xml.Response("version"=>"1.0") do |response|
  xml.Pause("length"=>"1")
  xml.Redirect("#{APP_URL}/callin/pause_then_start_conference?session=#{@session.id}&campaign=#{@campaign.id}")
end