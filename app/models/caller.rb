class Caller < ActiveRecord::Base
  include ActionController::UrlWriter
  include Deletable
  validates_presence_of :name, :on => :create, :message => "can't be blank"
  validates_format_of :email, :allow_blank => true, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :message => "Invalid email"
  has_and_belongs_to_many :campaigns
  belongs_to :user
  has_many :caller_sessions
  before_create :create_uniq_pin

  scope :active, lambda { {:conditions => ["active = ?", true]} }

  cattr_reader :per_page
  @@per_page = 25

  def create_uniq_pin
    uniq_pin=0
    while uniq_pin==0 do
      pin = rand.to_s[2..6]
      check = Caller.find_by_pin(pin)
      uniq_pin=pin if check.blank?
    end
    self.pin = uniq_pin
  end

  def callin(campaign, phone)
    response = TwilioClient.instance.account.calls.create(
        :from =>APP_NUMBER,
        :to => phone,
        :url => ready_callers_campaign_url(:id=>campaign.id, :host => 'http://localhost:3000')
    )
    CallerSession.create(:caller => self, :campaign => campaign, :sid => response["TwilioResponse"]["Call"]["Sid"])
  end
end
