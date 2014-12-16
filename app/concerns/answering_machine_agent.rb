##
# todo: document
#
class AnsweringMachineAgent
  attr_reader :household, :voter # tmp back compat

private
  def campaign
    @campaign ||= household.campaign
  end

public
  def initialize(household)
    @household = household
    @voter = household # tmp back compat
  end

  def leave_message?
    return campaign.use_recordings? && household.no_voicemail_delivered?

    # yes = false
    # if campaign.use_recordings?
    #   if (campaign.call_back_after_voicemail_delivery? &&
    #            household.no_voicemail_delivered?) ||
    #      !campaign.call_back_after_voicemail_delivery?
    #     yes = true
    #   end
    # end
    # yes
  end

  def call_back?
    campaign.call_back_after_voicemail_delivery?
  end

  def call_status
    # std path
    leave_message? ? CallAttempt::Status::VOICEMAIL : CallAttempt::Status::HANGUP
  end
end
