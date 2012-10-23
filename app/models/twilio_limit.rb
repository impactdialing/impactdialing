class TwilioLimit
  
  def self.get
    Resque.redis.get("twilio_limit").try(:to_f) || 4
  end
  
  def self.set(limit)
    Resque.redis.set("twilio_limit", limit)
  end
end