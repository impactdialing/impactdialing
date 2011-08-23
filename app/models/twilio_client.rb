class TwilioClient
  delegate :account, :to => lambda { self.instance }

  def self.instance
    Twilio::REST::Client.new TWILIO_ACCOUNT, TWILIO_AUTH
  end
end