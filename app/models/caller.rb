class Caller < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include Deletable
  validates_format_of :email, :allow_blank => true, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :message => "Invalid email"
  belongs_to :campaign
  belongs_to :account
  has_many :caller_sessions
  before_create :create_uniq_pin
  validates_uniqueness_of :email, :allow_nil => true
  #validates_presence_of :campaign_id

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

  def active_session(campaign)
    return {:caller_session => {:id => nil}} if self.campaign.nil?
    caller_sessions.available.on_campaign(campaign).last || {:caller_session => {:id => nil}}
  end
  
  def is_phones_only_and_preview_or_progressive?(campaign)
    is_phones_only? and (campaign.predictive_type == Campaign::Type::PREVIEW or campaign.predictive_type == Campaign::Type::PROGRESSIVE)
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
  
  def ask_instructions_choice(caller_session)
    Twilio::Verb.new do |v|
      v.gather(:numDigits => 1, :timeout => 10, :action => choose_instructions_option_caller_url(self, :session => caller_session, :host => Settings.host, :port => Settings.port), :method => "POST", :finishOnKey => "5") do
        v.say I18n.t(:caller_instruction_choice)
      end
    end.response
  end
  
  def instruction_choice_result(caller_choice, caller_session)
    if caller_choice == "*"
      is_phones_only_and_preview_or_progressive?(caller_session.campaign) ? caller_session.ask_caller_to_choose_voter : caller_session.start
    elsif caller_choice == "#"
      Twilio::Verb.new do |v|
        v.gather(:numDigits => 1, :timeout => 10, :action => choose_instructions_option_caller_url(self, :session => caller_session, :host => Settings.host, :port => Settings.port), :method => "POST", :finishOnKey => "5") do
          v.say I18n.t(:phones_only_caller_instructions)
        end
      end.response
    else
      ask_instructions_choice(caller_session)
    end
  end
  
  def choice_result(caller_choice, voter, caller_session)
    if caller_choice == "*"
      response = caller_session.phones_only_start
      caller_session.preview_dial(voter)
      response
    elsif caller_choice == "#"
      voter.skip
      caller_session.ask_caller_to_choose_voter
    else
      caller_session.ask_caller_to_choose_voter(voter, caller_choice)
    end
  end
  

end
