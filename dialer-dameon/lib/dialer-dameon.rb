# Your starting point for daemon specific classes. This directory is
# already included in your load path, so no need to specify it.

Dir[File.join(File.dirname(__FILE__), '../../', 'app/models') + "**/*.rb"].each {|file| 
      require file
      DaemonKit.logger.info "#{file}"
#      include self.class.const_get(File.basename(file).gsub('.rb','').split("_").map{|ea| ea.capitalize}.to_s)
}



class Dialer
  if DaemonKit.env=="development"
    APP_NUMBER="5104048117"
    APP_URL="http://www.hinodae.com:5555"
    TWILIO_ACCOUNT="ACc0208d4be3e204d5812af2813683243a"
    TWILIO_AUTH="4e179c64daa7c9f5108bd6623c98aea6"
  else
    TWILIO_ACCOUNT="AC422d17e57a30598f8120ee67feae29cd"
    TWILIO_AUTH="897298ab9f34357f651895a7011e1631"
    APP_NUMBER="4157020991"
    APP_URL="http://impact-app-balancer-912849015.us-east-1.elb.amazonaws.com"
  end
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
    require "hpricot"
    require "open-uri"
    voter.status="Call in progress"
    voter.save
    t = Twilio.new(TWILIO_ACCOUNT, TWILIO_AUTH)
#    a=t.call("POST", "Calls", {'IfMachine'=>"Hangup", 'Caller' => APP_NUMBER, 'Called' => voter.Phone, 'Url'=>"#{APP_URL}/callin/voterFindSession?campaign=#{campaign.id}&voter=#{voter.id}"})
    if !campaign.caller_id.blank? && campaign.caller_id_verified
      caller_num=campaign.caller_id
    else
      caller_num=APP_NUMBER
    end
    #DaemonKit.logger.info "APP_URL: #{APP_URL}"
    c = CallAttempt.new
    c.voter_id=voter.id
    c.campaign_id=campaign.id
    c.status="Call ready to dial"
    c.save
    if campaign.use_answering
      if campaign.use_recordings
        a=t.call("POST", "Calls", {'Timeout'=>campaign.answer_detection_timeout, 'Caller' => caller_num, 'Called' => voter.Phone, 'Url'=>"#{APP_URL}/callin/voterFindSession?campaign=#{campaign.id}&voter=#{voter.id}&attempt=#{c.id}", 'IfMachine'=>'Continue'})
      else
        a=t.call("POST", "Calls", {'Timeout'=>campaign.answer_detection_timeout, 'Caller' => caller_num, 'Called' => voter.Phone, 'Url'=>"#{APP_URL}/callin/voterFindSession?campaign=#{campaign.id}&voter=#{voter.id}&attempt=#{c.id}", 'IfMachine'=>'Hangup'})
      end
    else
      a=t.call("POST", "Calls", {'Timeout'=>"15", 'Caller' => caller_num, 'Called' => voter.Phone, 'Url'=>"#{APP_URL}/callin/voterFindSession?campaign=#{campaign.id}&voter=#{voter.id}&attempt=#{c.id}"})
    end
    require 'rubygems'
    require 'hpricot'
    @doc = Hpricot::XML(a)
    puts @doc if DaemonKit.env=="development"
    c.sid=(@doc/"Sid").inner_html
    c.status="Call in progress"
    c.save
    v = Voter.find(voter.id)
    v.last_call_attempt_id=c.id
    v.last_call_attempt_time=Time.now
    v.save

    # avail_campaign_hash = cache_get("avail_campaign_hash") {{}}
    # if !avail_campaign_hash.has_key?(campaign.id)
    #   avail_campaign_hash[campaign.id] = {"callers"=>[],"calls"=>[c]}
    # else
    #   avail_campaign_hash[campaign.id]["calls"] << c
    # end
    # cache_set("avail_campaign_hash") {avail_campaign_hash}

  end
end

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