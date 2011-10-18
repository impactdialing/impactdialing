class Caller < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include Deletable
  validates_presence_of :name, :on => :create, :message => "can't be blank"
  validates_format_of :email, :allow_blank => true, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :message => "Invalid email"
  has_many :caller_campaigns, :foreign_key => :caller_id
  has_many :campaigns, :through => :caller_campaigns
  belongs_to :account
  has_many :caller_sessions
  before_create :create_uniq_pin
  validates_uniqueness_of :email

  scope :active, where(:active => true)

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

  class << self
    include Rails.application.routes.url_helpers

    def ask_for_pin(attempt = 0)
      xml = if attempt > 2
              Twilio::Verb.new do |v|
                v.say "Incorrect Pin."
                v.hangup
              end
            else
              Twilio::Verb.new do |v|
                v.gather(:numDigits => 5, :timeout => 10, :action => identify_caller_url(:host => Settings.host, :attempt => attempt + 1), :method => "POST") do
                  v.say attempt == 0 ? "Please enter your pin." : "Incorrect Pin. Please enter your pin."
                end
              end
            end
      xml.response
    end
  end

  def callin(campaign, phone)
    session = CallerSession.create(:caller => self, :campaign => campaign)
    response = TwilioClient.instance.account.calls.create(
        :from =>APP_NUMBER,
        :to => phone,
        :url => caller_ready_callers_campaign_url(:id=>campaign.id, :caller_sid => session.sid, :host => APP_HOST)
    )
    #raise response.inspect
    session.update_attribute(:sid, response.sid)
    session
  end

  def phone
    #required for the form field.
  end

end
