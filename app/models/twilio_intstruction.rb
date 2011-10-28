class TwilioInstruction
  
  def self.insufficent_funds
    xml = Twilio::Verb.new do |v|
      v.say "Your account has insufficent funds"
      v.hangup
    end
   xml.response
  end
  
end