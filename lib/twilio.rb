class Twilio
  require 'net/http'

  DEFAULT_SERVER = "api.twilio.com"
  DEFAULT_PORT = 443
  DEFAULT_ROOT= "/2008-08-01/Accounts/"

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
    if service_method=="IncomingPhoneNumbers/Local" && ENV["RAILS_ENV"]=="development"  && !params.has_key?("SmsUrl")
      http = Net::HTTP.new(@server, "5000")  
      http.use_ssl=false
    else
      http = Net::HTTP.new(@server, @port)  
      http.use_ssl=true  
    end

#    RAILS_DEFAULT_LOGGER.info "#{@root}#{service_method}"
#    RAILS_DEFAULT_LOGGER.info "???#{service_method}???"
    
    #return 'err'    if service_method=="IncomingPhoneNumbers/Local" && (ENV["RAILS_ENV"]=="development" || ENV["RAILS_ENV"]=="dynamo_dev")
       
    if service_method=="IncomingPhoneNumbers/Local" && (ENV["RAILS_ENV"]=="development" || ENV["RAILS_ENV"]=="dynamo_dev") && !params.has_key?("SmsUrl")
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
        req = Net::HTTP::Post.new("#{@root}#{service_method}")    
      elsif http_method=="DELETE"
        req = Net::HTTP::Delete.new("#{@root}#{service_method}")    
      else
        req = Net::HTTP::Get.new("#{@root}#{service_method}")    
      end
      req.basic_auth @http_user, @http_password
    end
    #RAILS_DEFAULT_LOGGER.debug "#{@root}#{service_method}"

    req.set_form_data(params)
#    RAILS_DEFAULT_LOGGER.info  params
    response = http.start{http.request(req)}  
    #RAILS_DEFAULT_LOGGER.info  response.body if ENV["RAILS_ENV"]=="development"
#    RAILS_DEFAULT_LOGGER.info  response.body
    response.body
  end

end