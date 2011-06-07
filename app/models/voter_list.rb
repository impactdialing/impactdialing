class VoterList < ActiveRecord::Base
  belongs_to :campaign
  has_many :voters, :conditions => {:active => true}

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :user_id
end
