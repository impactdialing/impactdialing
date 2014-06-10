class TwilioLogger
  def self.error(response)
    exception = response['RestException'] || {}
    if exception['Message'] || exception['MoreInfo']
      msg = "TwilioRestException #{exception['Message']}" +
            " [#{exception['Code']}] [#{exception['Status']}]" +
            " (#{exception['MoreInfo']})"
    else
      msg = "TwilioRestException #{response}"
    end
    Rails.logger.error(msg)
  end
end