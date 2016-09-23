class TwilioLib
  require 'net/http'
  require 'em-http'
  include Rails.application.routes.url_helpers

  DEFAULT_PORT = 443 unless const_defined?('DEFAULT_PORT')
  DEFAULT_ROOT= "/2010-04-01/Accounts/" unless const_defined?('DEFAULT_ROOT')

  def initialize(accountguid=TWILIO_ACCOUNT, authtoken=TWILIO_AUTH, options = {})
    @server        = Settings.voip_api_url
    @port          = DEFAULT_PORT
    @root          = "#{DEFAULT_ROOT}#{accountguid}/"
    @http_user     = accountguid
    @http_password = authtoken
  end

  def twilio_calls_uri
    "https://#{Settings.voip_api_url}#{twilio_calls_url}"
  end

  def twilio_calls_url
    "#{@root}Calls.json"
  end

  def shared_callback_url_params(campaign, phone)
    {
      host: Settings.incoming_callback_host,
      port: Settings.twilio_callback_port,
      protocol: "http://",
      campaign_type: campaign.type,
      campaign_id: campaign.id,
      phone: phone
    }
  end

  def shared_failover_url_params(campaign, phone)
    if Settings.twilio_failover_host.present?
      shared_callback_url_params(campaign, phone).merge({
        host: Settings.twilio_failover_host
      })
    else
      shared_callback_url_params(campaign, phone)
    end
  end

  def make_call_params(campaign, phone)
    {
      'From'           => campaign.caller_id,
      'To'             => phone,
      'Url'            => twiml_lead_answered_url(shared_callback_url_params(campaign, phone).merge({
        event: 'incoming_call'
      })),
      'StatusCallback' => twiml_lead_completed_url(shared_callback_url_params(campaign, phone).merge({
        event: "call_ended"
      })),
      'Timeout'        => "15",
      'FallbackUrl'    => twiml_lead_answered_url(shared_failover_url_params(campaign, phone).merge({
        event: "incoming_call_fallback"
      }))
    }.merge!(amd_params(campaign))
  end

  def end_call(call_id)
    params = {'Status'=>"completed"}
    EventMachine::HttpRequest.new("https://#{@server}#{@root}Calls/#{call_id}").post :head => {'authorization' => [@http_user, @http_password]},:body => params
  end

  def end_call_sync(call_id)
    create_http_request("#{@root}Calls/#{call_id}", {'Status'=>"completed"}, Settings.voip_api_url)
  end

  def make_call(campaign, phone)
    params   = make_call_params(campaign, phone)
    response = create_http_request(twilio_calls_url, params, Settings.voip_api_url)
    response.body
  end

  def make_call_em(campaign, phone)
    params = make_call_params(campaign, phone)
    EventMachine::HttpRequest.new(twilio_calls_uri).post({
      :head => {
        'authorization' => [@http_user, @http_password]
      },
      :body => params
    })
  end

  def create_http_request(url, params, server)
    http         = Net::HTTP.new(server, @port)
    http.use_ssl = true
    req          = Net::HTTP::Post.new(url)

    req.basic_auth @http_user, @http_password
    req.set_form_data(params)

    RescueRetryNotify.on SocketError, 5 do
      http.start{ http.request(req) }
    end
  end

  def amd_params(campaign)
    if campaign.continue_on_amd
      {'IfMachine'=> 'Continue', "Timeout" => "30"}
    elsif campaign.caller_can_drop_message_manually
      {'Timeout' => '30'}
    elsif campaign.hangup_on_amd
      {'IfMachine'=> 'Hangup'}
    else
      {}
    end
  end

  def redirect_call(call_sid, redirect_url)
    EventMachine::HttpRequest.new("https://#{@server}#{@root}Calls/#{call_sid}.xml").post :head => {'authorization' => [@http_user, @http_password]},:body => {:Url => redirect_url,:Method => "POST" }
  end

  def call(http_method, service_method, params = {})
    http = Net::HTTP.new(@server, @port)
    http.use_ssl=true

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

    Rails.logger.debug "#{Settings.voip_api_url}#{@root}#{service_method}?#{params}"

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
    call_response                  = Hash.from_xml(response)['TwilioResponse']['Call']
    model_instance.tCallSegmentSid = call_response['Sid']
    model_instance.tAccountSid     = call_response['AccountSid']
    model_instance.tCalled         = call_response['To']
    model_instance.tCaller         = call_response['From']
    model_instance.tPhoneNumberSid = call_response['PhoneNumberSid']
    model_instance.tStatus         = call_response['Status']
    model_instance.tDuration       = call_response['Duration']
    model_instance.tPrice          = call_response['Price']
    model_instance.tFlags          = call_response['Direction']

    unless call_response['StartTime'].nil?
      model_instance.tStartTime = Time.parse(call_response['StartTime'])
    end
    unless call_response['EndTime'].nil?
      model_instance.tEndTime = Time.parse(call_response['EndTime'])
    end

    model_instance
  end
end
