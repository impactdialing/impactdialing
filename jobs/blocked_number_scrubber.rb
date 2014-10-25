class BlockedNumberScrubber
  @queue = :background_worker

  def self.perform(blocked_number_id)
    blocked_number = BlockedNumber.find blocked_number_id

    voters = Voter.where(account_id: blocked_number.account_id, phone: blocked_number.number)
    if blocked_number.campaign_id.present?
      voters = voters.where(campaign_id: blocked_number.campaign_id)
    end

    voters.update_all(blocked_number_id: blocked_number.id)
    Rails.logger.info "BlockedNumberScrubber Account[#{blocked_number.account_id}] Campaign[#{blocked_number.campaign_id}] Number[#{blocked_number.number}] marked #{voters.count} voters blocked."
  end
end
