class CallerIdObject
  def initialize(phone, friendly_name)
    @number        = PhoneNumber.new(phone)
    @friendly_name = @number
    @valid         = false
  end

  def twilio
    @twilio   ||= Twilio.new(TWILIO_ACCOUNT, TWILIO_AUTH)
  end
  
  def valid?
    @valid
  end

  def validation_code
    if @number.valid?
      api_result       = twilio.call("POST", "OutgoingCallerIds", {'PhoneNumber'=> @number, 'FriendlyName' => @friendly_name})
      @validation_code = (Hpricot::XML(api_result)/"ValidationCode").inner_html
    end
    @validation_code
  end

  def validate
    return false unless @number.valid?
    
    api_result = twilio.call("GET", "OutgoingCallerIds", {'PhoneNumber'=>@number})
    @valid     =
        begin
          code = (Hpricot::XML(api_result)/"Sid").inner_html
          code.presence
        rescue
          false
        end
  end
end
