class Transfer < ActiveRecord::Base
  belongs_to :script
  has_many :transfer_attempts
  include Rails.application.routes.url_helpers
  validates_presence_of :phone_number
  validates_length_of :phone_number, :minimum => 10, :unless => Proc.new{|transfer| transfer.phone_number && transfer.phone_number.start_with?("+")}
  before_validation :sanitize_phone
  validates :check_subscription_type

  def self.sanitize_phone(phonenumber)
    return phonenumber if phonenumber.blank?
    append = true if phonenumber.start_with?('+')
    sanitized = phonenumber.gsub(/[^0-9]/, "")
    append ? "+#{sanitized}" : sanitized
  end

  def sanitize_phone
    self.phone_number = Transfer.sanitize_phone(phone_number) if phone_number
  end



  module Type
    WARM = "warm"
    COLD = "cold"
  end

  def check_subscription_type
    if !script.transfer_types.include?(transfer_type)
      errors.add(:base, 'Your subscription does not allow transfering calls in this mode.')
    end
  end


  def dial(caller_session, call_attempt, voter, type)
    transfer_attempt = TransferAttempt.create(session_key: generate_session_key, transfer: self, campaign_id: caller_session.campaign_id, :status => CallAttempt::Status::RINGING, caller_session_id: caller_session.id, call_attempt_id: call_attempt.id, transfer_type: type)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    params = {'FallbackUrl' => TWILIO_ERROR, 'StatusCallback' => end_transfer_url(transfer_attempt, :host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, :protocol => "http://"),'Timeout' => "30"}
    response = Twilio::Call.make(voter.Phone, phone_number, connect_transfer_url(transfer_attempt, :host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, :protocol => "http://"),params)
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