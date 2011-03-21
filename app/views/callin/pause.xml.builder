xml.instruct! :xml, :version=>"1.0" 
xml.Response("version"=>"1.0") do |response|
  xml.Pause("length"=>"50")
end
RAILS_DEFAULT_LOGGER.debug(xml.target!) if DEBUG_TWIML