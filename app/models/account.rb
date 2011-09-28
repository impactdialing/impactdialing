class Account < ActiveRecord::Base
  has_many :users
  has_many :campaigns, :conditions => {:active => true}
  has_many :all_campaigns, :class_name => 'Campaign'
  has_many :recordings
  has_many :custom_voter_fields
  has_one :billing_account
  has_many :scripts
  has_many :callers
  has_many :voter_lists
  has_many :voters
  has_many :families
end
