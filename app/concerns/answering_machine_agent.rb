##
# To be used when
class AnsweringMachineAgent
  attr_reader :voter

private
  def campaign
    @campaign ||= voter.campaign
  end

public
  def initialize(voter)
    @voter = voter
  end

  def leave_message?
    yes = false
    if campaign.use_recordings?
      if (campaign.call_back_after_voicemail_delivery? &&
               voter.yet_to_receive_voicemail?) ||
         !campaign.call_back_after_voicemail_delivery?
        yes = true
      end
    end
    yes
  end

  def call_back?
    !leave_message? || campaign.call_back_after_voicemail_delivery?
  end

  def call_status
    # std path
    leave_message? ? CallAttempt::Status::VOICEMAIL : CallAttempt::Status::HANGUP
  end
end
