class CallerGroup < ActiveRecord::Base
  attr_accessible :name, :campaign_id

  validates :name, presence: true
  validates :campaign_id, presence: true
  has_many :callers
  belongs_to :campaign
  belongs_to :account

  after_save :reassign_callers

  def reassign_in_background
    self.callers.each { |c| c.update_attributes(campaign_id: campaign_id) }
  end

  private

  def reassign_callers
    Resque.enqueue(CallerGroupJob, self.id) if campaign_id_changed?
  end
end
