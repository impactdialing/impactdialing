xml.instruct! :xml, :version=>"1.0" 
xml.Response("version"=>"1.0") do |response|
  xml.Pause("length"=>"2")
  xml.Redirect("#{APP_URL}/callin/pause_then_start_conference?session=#{@session.id}&campaign=#{@campaign.id}")
end
Rails.logger.debug(xml.target!) if DEBUG_TWIML
