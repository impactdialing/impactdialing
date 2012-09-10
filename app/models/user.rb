class User < ActiveRecord::Base
  validates_uniqueness_of :email, :message => " is already in use"
  validates_format_of :email,
      :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
  validates_presence_of :email, :on => :create, :message => "can't be blank"

  belongs_to :account

  has_many :campaigns, :conditions => {:active => true}, :through => :account
  has_many :all_campaigns, :class_name => 'Campaign', :through => :account
  has_many :recordings, :through => :account
  has_many :custom_voter_fields, :through => :account
  has_one :billing_account, :through => :account
  has_many :scripts, :through => :account
  has_many :callers, :through => :account
  has_many :blocked_numbers, :through => :account
  has_many :downloaded_reports

  attr_accessor :new_password, :captcha
  validate :reverse_captcha
  validates_presence_of :new_password, :message => "can't be blank"
  validates_length_of :new_password, :within => 5..50, :message => "must be 5 characters or greater"

  before_save :hash_new_password, :if => :password_changed?
  
  module Role
    ADMINISTRATOR = "admin"
    SUPERVISOR = "supervisor"
  end
  
  def reverse_captcha
    if captcha.present?
      errors.add(:base, 'Spambots aren\'t welcome here')
    end
  end

  def password_changed?
    !!@new_password
  end

  def hash_new_password
    self.salt = SecureRandom.base64(8)
    self.hashed_password = Digest::SHA2.hexdigest(self.salt + @new_password)
  end
  

  def self.authenticate(email, password)
    if user = find_by_email(email)
      user if user.authenticate_with?(password)
    end
  end

  def authenticate_with?(password)
    return false unless password
   self.hashed_password == Digest::SHA2.hexdigest(self.salt + password)
  end

  def create_reset_code!
    update_attribute(:password_reset_code , Digest::SHA2.hexdigest(Time.new.to_s.split(//).sort_by{rand}.join))
  end

  def clear_reset_code
    update_attributes(:password_reset_code => nil)
  end

  def admin
    ["beans@beanserver.net", "michael@impactdialing.com","wolthuis@twilio.com","aa@beanserver.net"].index(self.email)
  end

  def admin?
    admin
  end
  
  def administrator?
    role == "admin"
  end
  
  def supervisor?
    role == "supervisor"
  end
  

  def show_voter_buttons
    ["beans@beanserver.net", "wolthuis@twilio.com"].index(self.email)
  end

  def show_voter_buttons?
    show_voter_buttons
  end

  def domain
    account.domain_name
  end
  
  def create_default_campaign
    @script = Script.default_script(self.account)
    @script.save
    @campaign = Progressive.new(name: "Demo campaign", caller_id: "4153475723", start_time: "01:00:00", end_time: "00:00:00", account_id: self.account.id, script_id: @script.id)
    @campaign.save
    @caller = Caller.new(name:"", email: self.email, password:"demo123", account_id: self.account.id, active: true, campaign_id: @campaign.id)
    @caller.save
    @voter_list = VoterList.new(name: "Demo list", account_id: self.account.id, campaign_id: @campaign.id)
    @voter_list.save
    @voter = Voter.new(Phone: "4152372444", LastName: "Lead", FirstName: "Demo", campaign_id: @campaign.id, account_id: self.account.id, voter_list_id: @voter_list.id)
    @voter.save  
  end
  
  def create_promo_balance
    p = Payment.new(:amount_paid=>9, :amount_remaining=>9, :account_id=>self.account.id, :notes=>"Trial credit")
    p.save
  end

  def create_recurly_account_code
    self.account.create_recurly_account_code
  end

  def send_welcome_email
    mailer = UserMailer.new
    return if Rails.env !="heroku"
    return if domain!="impactdialing.com" && domain!="localhost"
    Resque.enqueue(WelcomeEmailJob, self.id)
  end



end
