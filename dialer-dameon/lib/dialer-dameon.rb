# Your starting point for daemon specific classes. This directory is
# already included in your load path, so no need to specify it.
require File.join(File.dirname(__FILE__), '../../', 'app/models/deletable.rb')
Dir[File.join(File.dirname(__FILE__), '../../', 'app/models') + "**/*.rb"].each {|file|
      require file
      DaemonKit.logger.info "#{file}" if defined? DaemonKit
#      include self.class.const_get(File.basename(file).gsub('.rb','').split("_").map{|ea| ea.capitalize}.to_s)
}



if DaemonKit.env=="development"
  APP_NUMBER="5104048117"
  APP_URL="http://www.hinodae.com:5555"
  # TWILIO_ACCOUNT="ACc0208d4be3e204d5812af2813683243a"
  # TWILIO_AUTH="4e179c64daa7c9f5108bd6623c98aea6"

  TWILIO_ACCOUNT="AC422d17e57a30598f8120ee67feae29cd"
  TWILIO_AUTH="897298ab9f34357f651895a7011e1631"
  APP_NUMBER="8582254595"

else
  TWILIO_ACCOUNT="AC422d17e57a30598f8120ee67feae29cd"
  TWILIO_AUTH="897298ab9f34357f651895a7011e1631"
  APP_NUMBER="4157020991"
  APP_URL="http://admin.impactdialing.com"
end

class Dialer
  def self.account
    TWILIO_ACCOUNT
  end
  def self.auth
    TWILIO_AUTH
  end
  def self.appurl
    APP_URL
  end
  def self.startcall(voter, campaign)
    voter.dial_predictive #booya
  end
end

class TwilioLib
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
        req = Net::HTTP::Post.new("#{@root}#{service_method}")
      elsif http_method=="DELETE"
        req = Net::HTTP::Delete.new("#{@root}#{service_method}")
      else
        req = Net::HTTP::Get.new("#{@root}#{service_method}")
      end
      req.basic_auth @http_user, @http_password
    end
    #Rails.logger.debug "#{@root}#{service_method}"

    req.set_form_data(params)
    response = http.start{http.request(req)}
    response.body
  end

end
