class Caller < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include Deletable
  validates_format_of :email, :allow_blank => true, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :message => "Invalid email"
  has_many :caller_campaigns
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
                3.times do
                  v.gather(:numDigits => 5, :timeout => 10, :action => identify_caller_url(:host => Settings.host, :port => Settings.port, :attempt => attempt + 1), :method => "POST") do
                    v.say attempt == 0 ? "Please enter your pin." : "Incorrect Pin. Please enter your pin."
                  end
                end
              end
            end
      xml.response
    end
  end

  def callin(campaign)    
    response = TwilioClient.instance.account.calls.create(
        :from =>APP_NUMBER,
        :to => Settings.phone,
        :url => receive_call_url(:host => Settings.host, :port => Settings.port)
    )
  end

  def phone
    #required for the form field.
  end
  
  def info
    attributes.reject { |k, v| (k == "created_at") ||(k == "updated_at") }
  end
  

end
