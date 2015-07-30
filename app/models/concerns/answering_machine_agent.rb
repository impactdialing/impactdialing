##
# todo: document
#
class AnsweringMachineAgent
  attr_reader :campaign, :households, :phone

  def initialize(campaign, phone)
    @campaign   = campaign
    @households = campaign.dial_queue.households
    @phone      = phone
  end

  def leave_message?
    return campaign.use_recordings? && households.no_message_dropped?(phone)
  end

  def call_back?
    campaign.call_back_after_voicemail_delivery?
  end

  def call_status
    # std path
    leave_message? ? CallAttempt::Status::VOICEMAIL : CallAttempt::Status::HANGUP
  end

  def record_message_drop
    households.record_message_drop_by_phone(phone)
  end
end
