class TwilioLib
  require 'net/http'
  require 'em-http'
  include Rails.application.routes.url_helpers

  #DEFAULT_SERVER = "api.twilio.com" unless const_defined?('DEFAULT_SERVER')
  DEFAULT_SERVER = "voxeoproxy.herokuapp.com" unless const_defined?('DEFAULT_SERVER')
  DEFAULT_PORT = 443 unless const_defined?('DEFAULT_PORT')
  DEFAULT_ROOT= "/2010-04-01/Accounts/" unless const_defined?('DEFAULT_ROOT')

  def initialize(accountguid=TWILIO_ACCOUNT, authtoken=TWILIO_AUTH, options = {})
    @server = DEFAULT_SERVER
    @port = DEFAULT_PORT
    @root = "#{DEFAULT_ROOT}#{accountguid}/"
    @http_user = accountguid
    @http_password = authtoken
  end

  def end_call(call_id)
    params = {'Status'=>"completed"}
    EventMachine::HttpRequest.new("https://#{@server}#{@root}Calls/#{call_id}").post :head => {'authorization' => [@http_user, @http_password]},:body => params
  end

  def end_call_sync(call_id)
    create_http_request("#{@root}Calls/#{call_id}", {'Status'=>"completed"})
  end

  def make_call(campaign, voter, attempt)
    dc_codes = RedisDataCentre.data_centres(campaign.id)
    params = {'From'=> campaign.caller_id, "To"=> voter.Phone, 'FallbackUrl' => TWILIO_ERROR, "Url"=>incoming_call_url(attempt.call, host: DataCentre.incoming_call_host(dc_codes), port: Settings.twilio_callback_port, :protocol => "http://", event: "incoming_call", campaign_type: campaign.type),
      'StatusCallback' => call_ended_call_url(attempt.call, host: DataCentre.call_end_host(dc_codes), port:  Settings.twilio_callback_port, protocol: "http://", event: "call_ended", campaign_type: campaign.type),
      'Timeout' => "15"}
    params.merge!({'IfMachine'=> 'Continue', "Timeout" => "30"}) if campaign.answering_machine_detect
    response = create_http_request("https://#{voip_api_url(dc_codes)}#{@root}Calls.json", params)
    response.body
  end

  def create_http_request(url, params)
    http = Net::HTTP.new(@server, @port)
    http.use_ssl=true
    req = Net::HTTP::Post.new(url)
    req.basic_auth @http_user, @http_password
    req.set_form_data(params)
    http.start{http.request(req)}
  end


  def make_call_em(campaign, voter, attempt)
    dc_codes = RedisDataCentre.data_centres(campaign.id)
    params = {'From'=> campaign.caller_id, "To"=> voter.Phone, 'FallbackUrl' => TWILIO_ERROR, "Url"=>incoming_call_url(attempt.call, host: DataCentre.incoming_call_host(dc_codes), port: Settings.twilio_callback_port, protocol: "http://", event: "incoming_call", campaign_type: campaign.type),
      'StatusCallback' => call_ended_call_url(attempt.call, host: DataCentre.call_end_host(dc_codes), port:  Settings.twilio_callback_port, protocol: "http://", event: "call_ended", campaign_type: campaign.type),
      'Timeout' => "15", "DCCODES" => dc_codes}
    params.merge!({'IfMachine'=> 'Continue', "Timeout" => "30"}) if campaign.answering_machine_detect
    EventMachine::HttpRequest.new("https://#{voip_api_url(dc_codes)}#{@root}Calls.json").apost :head => {'authorization' => [@http_user, @http_password]},:body => params
  end

  def redirect_caller(call_sid, caller, session_id)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Call.redirect(call_sid, flow_caller_url(caller, :host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, :protocol => "http://", session_id: session_id, event: "start_conf"))
  end

  def redirect_call(call_sid, redirect_url)
    EventMachine::HttpRequest.new("https://#{@server}#{@root}Calls/#{call_sid}.xml").post :head => {'authorization' => [@http_user, @http_password]},:body => {:Url => redirect_url,:Method => "POST" }
  end




  def call(http_method, service_method, params = {})
    if service_method=="IncomingPhoneNumbers/Local" && Rails.env =="development"  && !params.has_key?("SmsUrl")
      http = Net::HTTP.new(@server, "5000")
      http.use_ssl=false
    else
      http = Net::HTTP.new(@server, @port)
      http.use_ssl=true
    end

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
    request = http.request(req)
    response = http.start{request}
    Rails.logger.info response.body
    response.body
  end
  
  def update_twilio_stats_by_model_em model_instance
    return if model_instance.sid.blank?
    t = TwilioLib.new(TWILIO_ACCOUNT,TWILIO_AUTH)
    EventMachine::HttpRequest.new("https://#{@server}#{@root}Calls/#{model_instance.sid}").aget :head => {'authorization' => [@http_user, @http_password]}
  end
  

  def update_twilio_stats_by_model model_instance
    return if model_instance.sid.blank?
    t = TwilioLib.new(TWILIO_ACCOUNT,TWILIO_AUTH)
    response = t.call("GET", "Calls/" + model_instance.sid, {})
    twilio_xml_parse(response, model_instance)
  end

  def twilio_xml_parse(response, model_instance)
    call_response = Hash.from_xml(response)['TwilioResponse']['Call']
    begin
      model_instance.tCallSegmentSid = call_response['Sid']
      model_instance.tAccountSid = call_response['AccountSid']
      model_instance.tCalled = call_response['To']
      model_instance.tCaller = call_response['From']
      model_instance.tPhoneNumberSid = call_response['PhoneNumberSid']
      model_instance.tStatus = call_response['Status']
      unless call_response['StartTime'].nil?
        model_instance.tStartTime = Time.parse(call_response['StartTime'])
      end
      unless call_response['EndTime'].nil?
       model_instance.tEndTime = Time.parse(call_response['EndTime'])
      end
      model_instance.tDuration = call_response['Duration']
      model_instance.tPrice = call_response['Price']
      model_instance.tFlags = call_response['Direction']
    rescue Exception
    end
    model_instance
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
