class DataCentre
  module Code
    ORL = "orl"
    ATL = "atl"
    LAS = "las"
    TWILIO = "twilio"
  end
  
  def self.code(dc_code)
    if dc_code.nil? || dc.empty?
      return Code::TWILIO 
    else
      return dc_code
    end
  end
  
end