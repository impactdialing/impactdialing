class User < ActiveRecord::Base
  validates_uniqueness_of :email, :message => " is already in use"
#  validates_confirmation_of :password
  validates_format_of :email,
      :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
#  validates_presence_of :orgname, :on => :create, :message => "can't be blank"
  validates_presence_of :email, :on => :create, :message => "can't be blank"
#  validates_presence_of :fname, :on => :create, :message => "can't be blank"
#  validates_presence_of :lname, :on => :create, :message => "can't be blank"
  validates_presence_of :hashed_password, :on => :create, :message => "can't be blank"
  validates_length_of :hashed_password, :within => 5..50, :on => :create, :message => "must be 5 characters or greater"
  has_many :campaigns, :conditions => {:active => true}
  attr_accessor :new_password
  before_save :hash_new_password, :if => :password_changed?
  has_many :recordings
  has_one :account

  def password_changed?
    !!@new_password
  end

  def hash_new_password
    self.salt = ActiveSupport::SecureRandom.base64(8)
    self.hashed_password = Digest::SHA2.hexdigest(self.salt + @new_password)
  end

  def self.authenticate(email, password)
    if user = find_by_email(email)
      if user.hashed_password == Digest::SHA2.hexdigest(user.salt + password)
        user
      end
    end
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

  def show_voter_buttons
    ["beans@beanserver.net", "wolthuis@twilio.com"].index(self.email)
  end
end
