class DataCentre
  module Code
    ORL = "orl"
    ATL = "atl"
    LAS = "las"
    TWILIO = "twilio"
  end

  def self.code(dc_code)
    Code::TWILIO
  end

  def self.twilio?(dc_code)
    true
  end

  def self.voip_api_url(dc_code)
    Settings.voip_api_url
  end

  def self.incoming_call_host(dc_code)
    Settings.incoming_callback_host
  end

  def self.call_end_host(dc_code)
    Settings.call_end_callback_host
  end

  def self.call_back_host(dc_code)
    Settings.twilio_callback_host
  end

  def self.call_back_host_from_provider(provider)
    Settings.twilio_callback_host
  end

  def self.protocol(dc_code)
    "https"
  end
end