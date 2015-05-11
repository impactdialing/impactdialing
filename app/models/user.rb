class User < ActiveRecord::Base
  validates_uniqueness_of :email
  validates_presence_of :email
  validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
  validates_presence_of :new_password, :on => :create
  validates_length_of :new_password, :within => 5..50, :on => :create
  validate :reverse_captcha

  belongs_to :account

  has_many :campaigns, :conditions => {:active => true}, :through => :account
  has_many :recordings, :through => :account
  has_many :custom_voter_fields, :through => :account
  has_many :scripts, :through => :account
  has_many :callers, :through => :account
  has_many :blocked_numbers, :through => :account
  has_many :downloaded_reports

  attr_accessor :new_password, :captcha

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

  def administrator?
    role == "admin"
  end

  def supervisor?
    role == "supervisor"
  end

  def domain
    account.domain_name
  end
end

# ## Schema Information
#
# Table name: `users`
#
# ### Columns
#
# Name                       | Type               | Attributes
# -------------------------- | ------------------ | ---------------------------
# **`id`**                   | `integer`          | `not null, primary key`
# **`fname`**                | `string(255)`      |
# **`lname`**                | `string(255)`      |
# **`orgname`**              | `string(255)`      |
# **`email`**                | `string(255)`      |
# **`active`**               | `boolean`          | `default(TRUE)`
# **`created_at`**           | `datetime`         |
# **`updated_at`**           | `datetime`         |
# **`hashed_password`**      | `string(255)`      |
# **`salt`**                 | `string(255)`      |
# **`password_reset_code`**  | `string(255)`      |
# **`phone`**                | `string(255)`      |
# **`account_id`**           | `integer`          |
# **`role`**                 | `string(255)`      |
#
