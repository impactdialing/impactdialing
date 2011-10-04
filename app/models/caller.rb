class Caller < ActiveRecord::Base
  include Deletable
  validates_presence_of :name, :on => :create, :message => "can't be blank"
  validates_format_of :email, :allow_blank => true, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :message => "Invalid email"
  has_and_belongs_to_many :campaigns
  belongs_to :account
  validates_uniqueness_of :email

  named_scope :active, lambda { { :conditions => ["callers.active = ?", true] }}

  cattr_reader :per_page
  @@per_page = 25

  def before_create
    uniq_pin=0
    while uniq_pin==0 do
      pin = rand.to_s[2..6]
      check = Caller.find_by_pin(pin)
      uniq_pin=pin if check.blank?
    end
    self.pin = uniq_pin
  end
end
