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
