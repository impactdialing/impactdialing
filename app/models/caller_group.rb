class CallerGroup < ActiveRecord::Base
  attr_accessible :name, :campaign_id

  validates :name, presence: true

  has_many :callers
  belongs_to :campaign

  before_save :reassign_callers

  private

  def reassign_callers
    puts 'self.campaign_id from model:'
    p self.campaign_id
    puts 'campaign_id_changed? from model:'
    p campaign_id_changed?
    p 'self.callers.all from model:'
    p self.callers.all
    if campaign_id_changed?
      self.callers.all.each do |c|
        puts 'self.campaign.id:'
        p self.campaign.id
        c.update_attributes(campaign_id: self.campaign.id)
      end
    end
  end
end
