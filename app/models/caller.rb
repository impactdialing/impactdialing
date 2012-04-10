class Caller < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include Deletable
  include ApplicationHelper::TimeUtils
  include ReportsHelper::Utilization
  include ReportsHelper::Billing
  validates_format_of :email, :allow_blank => true, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :message => "Invalid email"
  belongs_to :campaign
  belongs_to :account
  has_many :caller_sessions
  has_many :caller_identities
  has_many :call_attempts
  has_many :answers
  before_create :create_uniq_pin
  validates_uniqueness_of :email, :allow_nil => true
  validates_presence_of :campaign_id

  scope :active, where(:active => true)

  cattr_reader :per_page
  @@per_page = 25
  
  def identity_name
    is_phones_only?  ? name : email
  end
  
  def create_uniq_pin
    uniq_pin=0
    while uniq_pin==0 do
      pin = rand.to_s[2..6]
      check = Caller.find_by_pin(pin)
      uniq_pin=pin if check.blank?
    end
    self.pin = uniq_pin
  end

  
  def is_on_call?
    !caller_sessions.blank? && caller_sessions.on_call.size > 0
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

  def self.hold
    Twilio::Verb.new { |v| v.play("#{APP_URL}/wav/hold.mp3"); v.redirect(hold_call_path(:host => Settings.host, :port => Settings.port), :method => "GET")}.response
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

  def known_as
    return name unless name.blank?
    return email unless email.blank?
    ''
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
      campaign.is_preview_or_progressive ? caller_session.ask_caller_to_choose_voter : caller_session.start
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
  
  def reassign_to_another_campaign(caller_session)
    if caller_session.attempt_in_progress.nil?
      if self.is_phones_only?
        if (caller_session.campaign.predictive_type != "preview" && caller_session.campaign.predictive_type != "progressive")
          Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
          Twilio::Call.redirect(caller_session.sid, phones_only_caller_index_url(:host => Settings.host, :port => Settings.port, session_id: caller_session.id, :campaign_reassigned => true))
        end
      else
        caller_session.reassign_caller_session_to_campaign
        if campaign.predictive_type == Campaign::Type::PREVIEW || campaign.predictive_type == Campaign::Type::PROGRESSIVE
          caller_session.publish('conference_started', {}) 
        else
          caller_session.publish('caller_connected_dialer', {})
        end
      end
    end
  end

  def answered_call_stats(from, to, campaign)
    responses = self.answers.within(from, to).with_campaign_id(campaign.id).count(
      :joins => [:question, :possible_response],
      :group => ["questions.text", "possible_responses.value"]
    )
    responses.inject({}) do |acc, curr|
      question, answer = curr.first
      total_for_question = responses.select { |r| r.first == question }.values.reduce(:+)
      acc[question] = {:total => {:count => total_for_question, :percentage => 100 }} unless acc[question]
      acc[question][answer] = {:count => curr.last, :percentage => curr.last / total_for_question.to_f * 100 }
      acc
    end
  end
  
  def already_on_call
    Twilio::Verb.new do |v|
      v.say I18n.t(:indentical_caller_on_call)
      v.hangup
    end.response
  end
  
  def create_caller_session(session_key, sid)
    caller_sessions.create(on_call: false, available_for_call: false, session_key: session_key, campaign: campaign , sid: sid, starttime: Time.now)
  end
  
  def create_caller_identity(session_key)
    caller_identities.create(session_key: session_key, pin: create_uniq_pin)    
  end
  

end
