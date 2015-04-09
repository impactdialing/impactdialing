class TwilioLogger
  def self.error(response)
    exception = response['RestException'] || {}
    if exception['Message'] || exception['MoreInfo']
      msg = "#{exception['Message']} (#{exception['Code']}) (#{exception['Status']}) (#{exception['MoreInfo']})"
      Rails.logger.error("[TwilioRestException] #{msg}")
    end
    Rails.logger.error("[TwilioRestExceptionResponse] #{response}")
  end
end