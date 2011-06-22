class User < ActiveRecord::Base
  validates_uniqueness_of :email, :message => " is already in use"
  validates_format_of :email,
      :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
  validates_presence_of :email, :on => :create, :message => "can't be blank"

  has_many :campaigns, :conditions => {:active => true}
  has_many :recordings
  has_one :account
  has_many :scripts
  has_many :callers

  attr_accessor :new_password
  validates_presence_of :new_password, :on => :create, :message => "can't be blank"
  validates_length_of :new_password, :within => 5..50, :on => :create, :message => "must be 5 characters or greater"

  before_save :hash_new_password, :if => :password_changed?

  def password_changed?
    !!@new_password
  end

  def hash_new_password
    self.salt = ActiveSupport::SecureRandom.base64(8)
    self.hashed_password = Digest::SHA2.hexdigest(self.salt + @new_password)
  end

  def self.authenticate(email, password)
    if user = find_by_email(email)
      user if user.authenticate_with?(password)
    end
  end

  def authenticate_with?(password)
   self.hashed_password == Digest::SHA2.hexdigest(self.salt + password)
  end

  def create_reset_code
    update_attributes(:password_reset_code => Digest::SHA2.hexdigest(Time.new.to_s.split(//).sort_by{rand}.join))
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

  def show_voter_buttons
    ["beans@beanserver.net", "wolthuis@twilio.com"].index(self.email)
  end

  def show_voter_buttons?
    show_voter_buttons
  end
end
