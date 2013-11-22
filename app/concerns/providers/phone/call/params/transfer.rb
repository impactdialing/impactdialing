class Providers::Phone::Call::Params::Transfer
  attr_reader :transfer, :transfer_attempt, :voter, :type

  include Rails.application.routes.url_helpers

  def initialize(transfer, type)
    @transfer         = transfer
    @transfer_attempt = transfer.transfer_attempts.last
    @voter            = transfer_attempt.caller_session.voter_in_progress
    @type             = type == :default ? :connect : type
  end

  def from
    return voter.phone
  end

  def to
    return transfer.phone_number
  end

  def params
    return {
      'FallbackUrl' => TWILIO_ERROR,
      'StatusCallback' => end_url,
      'Timeout' => "30"
    }
  end

  def url_options
    return Providers::Phone::Call::Params.default_url_options
  end

  def url
    method_name = "#{type}_url"
    return send(method_name)
  end

  def end_url
    return end_transfer_url(transfer_attempt, url_options)
  end

  def connect_url
    return connect_transfer_url(transfer_attempt, url_options)
  end
end
