class BlockedNumber < ActiveRecord::Base
  belongs_to :account
  belongs_to :campaign
  validates_presence_of :number
  validates_length_of :number, :minimum => 10
  validates_numericality_of :number
  validates_presence_of :account
  before_validation :sanitize_phone
  scope :for_campaign, lambda {|campaign| where("campaign_id is NULL OR campaign_id = ?", campaign.id)}

  def sanitize_phone
    self.number=self.number.gsub(/[\(\)\+ -]/, "") if self.number!=nil
  end
end

# ## Schema Information
#
# Table name: `blocked_numbers`
#
# ### Columns
#
# Name               | Type               | Attributes
# ------------------ | ------------------ | ---------------------------
# **`id`**           | `integer`          | `not null, primary key`
# **`number`**       | `string(255)`      |
# **`account_id`**   | `integer`          |
# **`created_at`**   | `datetime`         |
# **`updated_at`**   | `datetime`         |
# **`campaign_id`**  | `integer`          |
#
# ### Indexes
#
# * `index_blocked_numbers_account_id_campaign_id`:
#     * **`account_id`**
#     * **`campaign_id`**
#
