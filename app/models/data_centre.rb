class DataCentre
  module Code
    ORL = "orl"
    ATL = "atl"
    LAS = "las"
    TWILIO = "twilio"
  end
  
  def self.code(dc_code)
    if dc_code.nil? || dc_code.empty?
      return Code::TWILIO 
    else
      return dc_code
    end
  end
  
  def self.twilio?(dc_code)
    dc_code.nil? || dc_code.empty? || dc_code == Code::TWILIO
  end
  
  def self.voxeo?(dc_code)
    !twilio
  end
  
  def self.voip_api_url(dc_code)
    dc_code == Code::TWILIO ? Settings.voip_api_url : Settings.voxeo_voip_api_url
  end
  
  def self.incoming_call_host(dc_code)
    dc_code == Code::TWILIO ? Settings.incoming_callback_host : Settings.voxeo_incoming_callback_host
  end

  def self.call_end_host(dc_code)
    dc_code == Code::TWILIO ? Settings.call_end_callback_host : Settings.voxeo_call_end_callback_host
  end
  
  def self.call_back_host(dc_code)
    twilio?(dc_code) ? Settings.twilio_callback_host : Settings.voxeo_callback_host     
  end
  
  def self.call_back_host_from_provider(provider)
    provider == "voxeo" ? Settings.voxeo_callback_host : Settings.twilio_callback_host
  end
  
  
end