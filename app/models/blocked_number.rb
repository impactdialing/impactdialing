class BlockedNumber < ActiveRecord::Base
  belongs_to :user
  validates_presence_of :number
  validates_length_of :number, :minimum => 10
  validates_numericality_of :number
  validates_presence_of :user
  before_validation :sanitize_phone
  
  
  def sanitize_phone
    self.number=self.number.gsub(/[\(\)\+ -]/, "") if self.number!=nil
  end

end
