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
    require "hpricot"
    require "open-uri"
    voter.status="Call in progress"
    voter.save
    t = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    if !campaign.caller_id.blank? && campaign.caller_id_verified
      caller_num=campaign.caller_id
    else
      caller_num=APP_NUMBER
    end
    c = CallAttempt.new
    c.dialer_mode=campaign.predective_type
    c.voter_id=voter.id
    c.campaign_id=campaign.id
    c.status="Call ready to dial"
    c.save
    if campaign.predective_type.index("robo,")
      a=t.call("POST", "Calls", {'Timeout'=>"15", 'IfMachine'=>'Hangup', 'Caller' => caller_num, 'Called' => voter.Phone, 'Url'=>"#{APP_URL}/robo/#{campaign.predective_type.split(",").last}&campaign=#{campaign.id}&voter=#{voter.id}&attempt=#{c.id}"})
    elsif campaign.predective_type=="preview"
      a=t.call("POST", "Calls", {'Timeout'=>"20", 'Caller' => caller_num, 'Called' => voter.Phone, 'Url'=>"#{APP_URL}/callin/voterFindSession?campaign=#{campaign.id}&voter=#{voter.id}&attempt=#{c.id}"})
    elsif campaign.use_answering
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
    Rails.logger.info a
    @doc = Hpricot::XML(a)
    puts @doc if Rails.env=="development"
    c.sid=(@doc/"Sid").inner_html
    c.status="Call in progress"
    c.save
    v = Voter.find(voter.id)
    v.last_call_attempt_id=c.id
    v.last_call_attempt_time=Time.now
    v.save
  end
end
