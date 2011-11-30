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
  has_many :blocked_numbers
  has_many :moderators

  def new_billing_account
    BillingAccount.create(:account => self)
  end

  def paid?
    Rails.logger.debug('Deprecated! Call #activated? instead.')
    Rails.logger.debug("Called from #{caller[1]}")
    activated?
  end
  
  def toggle_call_recording!
    self.record_calls = !self.record_calls
    self.save
  end

end
