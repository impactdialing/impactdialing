class VoterList < ActiveRecord::Base
  has_and_belongs_to_many :campaigns
  has_many :voters, :conditions => {:active => true}  
end
