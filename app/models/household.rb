class Household < ActiveRecord::Base
  # no attr_accessible for now; these records are handled entirely behind-the-scenes
  belongs_to :account
  
  belongs_to :campaign, counter_cache: true
  delegate :dial_queue, to: :campaign
  delegate :call_back_after_voicemail_delivery?, to: :campaign

  has_many :call_attempts
  has_many :voters

  bitmask :blocked, as: [:cell, :dnc], null: false

  before_validation :sanitize_phone
  validates_presence_of :phone, :account, :campaign
  validates_length_of :phone, minimum: 10, maximum: 16
  validates_uniqueness_of :phone, scope: :campaign_id

  scope :active, without_blocked(:cell).without_blocked(:dnc)
  scope :not_dialed, where('households.status = "not called"')
  scope :dialed, where('households.status <> "not called"')
  scope :failed, where('households.status = ?', CallAttempt::Status::FAILED)
  scope :presented_within, lambda{ |from, to|
    where('households.presented_at >= ?', from).
    where('households.presented_at <= ?', to)
  }
  scope :with_message_drop, joins(:call_attempts).where('call_attempts.recording_id IS NOT NULL')
  scope :with_manual_message_drop, with_message_drop.where('call_attempts.recording_delivered_manually = ?', true)
  scope :with_auto_message_drop, with_message_drop.where('call_attempts.recording_delivered_manually = ?', false)
  scope :presentable, lambda{ |campaign|
    where('households.presented_at IS NULL OR households.presented_at < ?', campaign.recycle_rate.hours.ago)
  }
  scope :available, lambda{ |campaign|
    active.
    presentable(campaign).
    where(
      "households.status IN (?)",
      CallAttempt::Status.available_list(campaign)
    )
  }
  scope :not_available, lambda{ |campaign|
    where(
      "households.status IN (?) OR households.presented_at > ? OR households.blocked > 0",
      CallAttempt::Status.not_available_list(campaign),
      campaign.recycle_rate.hours.ago
    )
  }

private
  def sanitize_phone
    self.phone = PhoneNumber.sanitize(phone)
  end

public
  def last_call_attempt
    call_attempts.last
  end
  # make activerecord-import work with bitmask_attributes
  def blocked=(raw_value)
    if raw_value.is_a?(Fixnum) && raw_value <= Household.bitmasks[:blocked].values.sum
      self.send(:write_attribute, :blocked, raw_value)
    else
      values = raw_value.kind_of?(Array) ? raw_value : [raw_value]
      self.blocked.replace(values.reject{|value| value.blank?})
    end
  end

  def cache?
    not_failed? and not_blocked? and not_complete?
  end

  def failed?
    status == CallAttempt::Status::FAILED
  end

  def not_failed?
    not failed?
  end

  def voicemail_delivered?
    call_attempts.with_recording.count > 0
  end

  def no_voicemail_delivered?
    not voicemail_delivered?
  end

  def complete?
    no_presentable_voters? or (voicemail_delivered? and (not call_back_after_voicemail_delivery?))
  end

  def not_complete?
    not complete?
  end

  def not_blocked?
    not blocked?
  end

  def update_dial_queue(status, presented_at)
    self.status       = status
    self.presented_at = presented_at

    dial_queue.dialed(self)
  end

  # Handle a failed call
  def failed!
    update_dial_queue(CallAttempt::Status::FAILED, Time.now.utc)
    save
  end

  # Handle a successful call
  def dialed(call_attempt)
    update_dial_queue(call_attempt.status, call_attempt.call_end)
  end

  def presented_recently?
    presented_at.to_i > campaign.recycle_rate.hours.ago.to_i
  end

  def no_presentable_voters?
    voters.count == voters.not_presentable(campaign).count
  end
end

# ## Schema Information
#
# Table name: `households`
#
# ### Columns
#
# Name                | Type               | Attributes
# ------------------- | ------------------ | ---------------------------
# **`id`**            | `integer`          | `not null, primary key`
# **`account_id`**    | `integer`          | `not null`
# **`campaign_id`**   | `integer`          | `not null`
# **`voters_count`**  | `integer`          | `default(0), not null`
# **`phone`**         | `string(255)`      | `not null`
# **`blocked`**       | `integer`          | `default(0), not null`
# **`status`**        | `string(255)`      | `default("not called"), not null`
# **`presented_at`**  | `datetime`         |
# **`created_at`**    | `datetime`         | `not null`
# **`updated_at`**    | `datetime`         | `not null`
#
# ### Indexes
#
# * `index_households_on_account_id`:
#     * **`account_id`**
# * `index_households_on_account_id_and_campaign_id_and_phone` (_unique_):
#     * **`account_id`**
#     * **`campaign_id`**
#     * **`phone`**
# * `index_households_on_blocked`:
#     * **`blocked`**
# * `index_households_on_campaign_id`:
#     * **`campaign_id`**
# * `index_households_on_phone`:
#     * **`phone`**
# * `index_households_on_presented_at`:
#     * **`presented_at`**
# * `index_households_on_status`:
#     * **`status`**
#
