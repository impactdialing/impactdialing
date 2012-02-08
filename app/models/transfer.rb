class Transfer < ActiveRecord::Base
  belongs_to :script
  has_many :transfer_attempts
  include Rails.application.routes.url_helpers
  
  module Type
    WARM = "warm"
    COLD = "cold"
  end
  
  
  def dial(caller_session, call_attempt, voter, type)
    transfer_attempt = TransferAttempt.create(session_key: generate_session_key, transfer: self, campaign_id: caller_session.campaign_id, :status => CallAttempt::Status::RINGING, caller_session_id: caller_session.id, call_attempt_id: call_attempt.id, transfer_type: type)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    params = {'FallbackUrl' => TWILIO_ERROR, 'StatusCallback' => end_transfer_url(transfer_attempt, :host => Settings.host, :port => Settings.port),'Timeout' => "30"}
    response = Twilio::Call.make(voter.Phone, phone_number, connect_transfer_url(transfer_attempt, :host => Settings.host, :port => Settings.port),params)
    if response["TwilioResponse"]["RestException"]
      transfer_attempt.update_attributes(status: CallAttempt::Status::FAILED)
      return
    end
    transfer_attempt.update_attributes(:sid => response["TwilioResponse"]["Call"]["Sid"])
 end
 
 def generate_session_key
   secure_digest(Time.now, (1..10).map{ rand.to_s })
 end
 
 def secure_digest(*args)
   Digest::SHA1.hexdigest(args.flatten.join('--'))
 end
 
 
  
end