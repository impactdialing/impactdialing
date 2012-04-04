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

  def custom_fields
    custom_voter_fields
  end
  
  def create_chargify_customer_id
    return self.chargify_customer_id if !self.chargify_customer_id.nil?
    user = User.find_by_account_id(self.id)
    customer = Chargify::Customer.create(
      :first_name   => user.fname,
      :last_name    => user.lname,
      :email        => user.email,
      :organization => user.orgname
    )
    self.chargify_customer_id=customer.id
    self.save
    self.chargify_customer_id
  end
  
  def insufficient_funds
    Twilio::Verb.new do |v|
      v.say "Your account has insufficent funds"
      v.hangup
    end.response
  end
  

end
