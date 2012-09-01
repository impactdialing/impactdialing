class CallerGroup < ActiveRecord::Base
  attr_accessible :name, :campaign_id

  validates :name, presence: true
  has_many :callers
  belongs_to :campaign
  belongs_to :account

  before_save :reassign_callers

  private

  def reassign_callers
    self.callers.each { |c| c.update_attributes(campaign_id: campaign_id) } if campaign_id_changed?
  end
end
