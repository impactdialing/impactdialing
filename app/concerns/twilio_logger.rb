class TwilioLogger
  def self.error(response)
    exception = response['RestException']
    msg = "TwilioRestException #{exception['Message']}" +
          " [#{exception['Code']}] [#{exception['Status']}]" +
          " (#{exception['MoreInfo']})"
    Rails.logger.error(msg)
  end
end