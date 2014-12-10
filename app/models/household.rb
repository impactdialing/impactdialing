class Household < ActiveRecord::Base
  # no attr_accessible for now; these records are handled entirely behind-the-scenes
  belongs_to :account
  belongs_to :campaign
  belongs_to :last_call_attempt, class_name: 'CallAttempt'
  has_many :call_attempts
  has_many :voters

  bitmask :blocked, as: [:cell, :dnc], null: false

  before_validation :sanitize_phone
  validates_presence_of :phone, :account, :campaign
  validates_length_of :phone, minimum: 10, maximum: 16
  validates_uniqueness_of :phone, scope: :campaign_id

private
  def sanitize_phone
    self.phone = PhoneNumber.sanitize(phone)
  end

public
  # make activerecord-import work with bitmask_attributes
  def blocked=(raw_value)
    if raw_value.is_a?(Fixnum) && raw_value <= Household.bitmasks[:blocked].values.sum
      self.send(:write_attribute, :blocked, raw_value)
    else
      values = raw_value.kind_of?(Array) ? raw_value : [raw_value]
      self.blocked.replace(values.reject{|value| value.blank?})
    end
  end

  def in_dnc?
    blocked?(:cell) || blocked?(:dnc)
  end
end

# ## Schema Information
#
# Table name: `households`
#
# ### Columns
#
# Name                        | Type               | Attributes
# --------------------------- | ------------------ | ---------------------------
# **`id`**                    | `integer`          | `not null, primary key`
# **`account_id`**            | `integer`          | `not null`
# **`campaign_id`**           | `integer`          | `not null`
# **`last_call_attempt_id`**  | `integer`          |
# **`phone`**                 | `string(255)`      | `not null`
# **`blocked`**               | `integer`          | `default(0), not null`
# **`status`**                | `string(255)`      | `default("not called"), not null`
# **`presented_at`**          | `datetime`         |
# **`created_at`**            | `datetime`         | `not null`
# **`updated_at`**            | `datetime`         | `not null`
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
# * `index_households_on_last_call_attempt_id`:
#     * **`last_call_attempt_id`**
# * `index_households_on_phone`:
#     * **`phone`**
# * `index_households_on_presented_at`:
#     * **`presented_at`**
# * `index_households_on_status`:
#     * **`status`**
#
