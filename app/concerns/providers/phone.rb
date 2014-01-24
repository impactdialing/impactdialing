module Providers::Phone
  def self.default_options
    return {
      retry_up_to: ENV["TWILIO_RETRIES"]
    }
  end

  def self.options(opts)
    return default_options.merge(opts)
  end
end