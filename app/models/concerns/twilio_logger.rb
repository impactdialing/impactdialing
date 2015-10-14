class TwilioLogger
  def self.error(response)
    exception = response['RestException'] || {}
    if exception['Message'] || exception['MoreInfo']
      msg = "Code[#{exception['Code']}] Status[#{exception['Status']}] MoreInfo[#{exception['MoreInfo']}] #{exception['Message']}" 
      log(msg)
    end
    log("[Response] #{response}")
  end

  def self.log(message)
    Rails.logger.error("[TwilioRestException] #{message}")
  end
end
