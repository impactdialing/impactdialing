class TwilioLib
  require 'net/http'

  DEFAULT_SERVER = "api.twilio.com" unless const_defined?('DEFAULT_SERVER')
  DEFAULT_PORT = 443 unless const_defined?('DEFAULT_PORT')
  DEFAULT_ROOT= "/2008-08-01/Accounts/" unless const_defined?('DEFAULT_ROOT')

  def accountguid
  end

  def initialize(accountguid=TWILIO_ACCOUNT, authtoken=TWILIO_AUTH, options = {})
    @server = DEFAULT_SERVER
    @port = DEFAULT_PORT
    @root = "#{DEFAULT_ROOT}#{accountguid}/"
    @http_user = accountguid
    @http_password = authtoken
  end


  def call(http_method, service_method, params = {})
    if service_method=="IncomingPhoneNumbers/Local" && Rails.env =="development"  && !params.has_key?("SmsUrl")
      http = Net::HTTP.new(@server, "5000")
      http.use_ssl=false
    else
      http = Net::HTTP.new(@server, @port)
      http.use_ssl=true
    end

#    Rails.logger.info "#{@root}#{service_method}"
#    Rails.logger.info "???#{service_method}???"

    #return 'err'    if service_method=="IncomingPhoneNumbers/Local" && (Rails.env =="development" || Rails.env =="dynamo_dev")

    if service_method=="IncomingPhoneNumbers/Local" && (Rails.env =="development" || Rails.env =="dynamo_dev") && !params.has_key?("SmsUrl")
      return '<?xml version="1.0" encoding="UTF-8"?>
      <TwilioResponse>
        <IncomingPhoneNumber>
          <Sid>PNe536dfda7c6184afab78d980cb8cdf43</Sid>
          <AccountSid>AC35542fc30a091bed0c1ed511e1d9935d</AccountSid>
          <FriendlyName>My Company Line</FriendlyName>
          <PhoneNumber>' + DEVDID + '</PhoneNumber>
          <Url>http://mycompany.com/handleNewCall.php</Url>
          <Method>POST</Method>
          <DateCreated>Tue, 01 Apr 2008 11:26:32 -0700</DateCreated>
          <DateUpdated>Tue, 01 Apr 2008 11:26:32 -0700</DateUpdated>
        </IncomingPhoneNumber>
      </TwilioResponse>
      '
    else
      if http_method=="POST"
        req = Net::HTTP::Post.new("#{@root}#{service_method}?#{params}")
      elsif http_method=="DELETE"
        req = Net::HTTP::Delete.new("#{@root}#{service_method}?#{params}")
      else
        if params.nil?
          req = Net::HTTP::Get.new("#{@root}#{service_method}")
         else
           req = Net::HTTP::Get.new("#{@root}#{service_method}?".concat(params.collect { |k,v| "#{k}=#{CGI::escape(v.to_s)}" }.join('&')))
        end
      end
      req.basic_auth @http_user, @http_password
    end
    Rails.logger.debug "#{DEFAULT_SERVER}#{@root}#{service_method}?#{params}" if Rails.env =="development"

    req.set_form_data(params)
#    Rails.logger.info  params
    response = http.start{http.request(req)}
    Rails.logger.info  response.body if Rails.env =="development"
#    Rails.logger.info  response.body
    response.body
  end

  def update_twilio_stats_by_model model_instance
    require 'rubygems'
    require 'hpricot'
    return if model_instance.sid.blank?
    t = TwilioLib.new(TWILIO_ACCOUNT,TWILIO_AUTH)
    @a=t.call("GET", "Calls/" + model_instance.sid, {})
    @doc = Hpricot::XML(@a)
    puts @doc
    call = twilio_xml_parse(@doc, model_instance)
  end

  def twilio_xml_parse(doc,model_instance)
    (doc/:Call).each do |status|
        model_instance.tCallSegmentSid = status.at("CallSegmentSid").innerHTML
        model_instance.tAccountSid = status.at("AccountSid").innerHTML
        model_instance.tCalled = status.at("Called").innerHTML
        model_instance.tCaller = status.at("Caller").innerHTML
        model_instance.tPhoneNumberSid = status.at("PhoneNumberSid").innerHTML
        model_instance.tStatus = status.at("Status").innerHTML
        model_instance.tStartTime = Time.parse(status.at("StartTime").innerHTML)
        model_instance.tEndTime = Time.parse(status.at("EndTime").innerHTML)
        Rails.logger.info "!!!!!!!!! Twilio End Time for id : #{model_instance.id}: #{status.at("EndTime").innerHTML}"
        model_instance.tDuration = status.at("Duration").innerHTML
        model_instance.tPrice = status.at("Price").innerHTML
        model_instance.tFlags = status.at("Flags").innerHTML
        model_instance.save
      end
  end


  def twilio_status_lookup(code)

    case code
      when 0 then "Not Yet Dialed"
      when 1 then "In Progress"
      when 2 then "Complete"
      when 3 then "Failed - Busy"
      when 4 then "Failed - Application Error"
      when 5 then "Failed - No Answer"
    end

  end

end
