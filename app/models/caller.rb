class Caller < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include Deletable
  include SidekiqEvents
  validates_format_of :email, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :message => "Invalid",  :if => lambda {|s| !s.is_phones_only  }
  validates_presence_of :email,  :if => lambda {|s| !s.is_phones_only  }
  validates_presence_of :name,  :if => lambda {|s| s.is_phones_only }
  validates_uniqueness_of :email
  belongs_to :campaign
  belongs_to :account
  belongs_to :caller_group
  has_many :caller_sessions
  has_many :caller_identities
  has_many :call_attempts
  has_many :answers
  before_create :create_uniq_pin
  before_validation :assign_to_caller_group_campaign
  before_save :reassign_caller_campaign
  validates :campaign_id, presence: true
  validate :restored_caller_has_campaign

  scope :active, where(:active => true)

  delegate :subscription_allows_caller?, :to => :account
  delegate :activated?, :to => :account
  delegate :funds_available?, :to => :account
  delegate :as_time_zone, :to=> :campaign

  cattr_reader :per_page
  @@per_page = 25

  def identity_name
    is_phones_only?  ? name : email
  end

  def reassign_caller_campaign
    if campaign_id_changed?
      caller_sessions.on_call.each {|caller_session| caller_session.reassign_to_another_campaign(self.campaign_id) }
    end
  end

  def create_uniq_pin
    self.pin = CallerIdentity.create_uniq_pin
  end

  def is_on_call?
    !caller_sessions.blank? && caller_sessions.on_call.size > 1
  end

  class << self
    include Rails.application.routes.url_helpers

    def ask_for_pin(attempt = 0, provider)
      xml = if attempt > 2
              Twilio::Verb.new do |v|
                v.say "Incorrect Pin."
                v.hangup
              end
            else
              Twilio::Verb.new do |v|
                3.times do
                  v.gather(:finishOnKey => '*', :timeout => 10, :action => identify_caller_url(:host => DataCentre.call_back_host_from_provider(provider), :port => Settings.twilio_callback_port, :protocol => "http://", :attempt => attempt + 1), :method => "POST") do
                    v.say attempt == 0 ? "Please enter your pin and then press star." : "Incorrect Pin. Please enter your pin and then press star."
                  end
                end
              end
            end
      xml.response
    end
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


  def answered_call_stats(from, to, campaign)
    result = Hash.new
    question_ids = Answer.where(campaign_id: campaign.id).uniq.pluck(:question_id)
    answer_count = Answer.select(:possible_response_id).
      where(:campaign_id => campaign.id, :caller_id => self.id).
      within(from, to).group("possible_response_id").count
    total_answers = Answer.select(:question_id).
      where(:campaign_id => campaign.id, :caller_id => self.id).
      within(from, to).group("question_id").count
    questions = Question.where(id: question_ids)
    questions.each do |question|
      result[question.text] = question.possible_responses.collect { |possible_response| possible_response.stats(answer_count, total_answers) }
      result[question.text] << {answer: "[No response]", number: 0, percentage:  0} unless question.possible_responses.find_by_value("[No response]").present?
    end
    result
  end

  def create_caller_session(session_key, sid, caller_type)
    if is_phones_only?
      caller_session = PhonesOnlyCallerSession.create(session_key: session_key, campaign: campaign , sid: sid, starttime: Time.now, caller_type: caller_type, state: 'initial', caller: self, on_call: true, script_id: campaign.script_id)
    else
      caller_session =  WebuiCallerSession.create(on_call: false, available_for_call: false, session_key: session_key, campaign: campaign , sid: sid, starttime: Time.now, caller_type: caller_type, state: 'initial', caller: self, on_call: true, script_id: campaign.script_id)
    end
    caller_session
  end

  def started_calling(session)
    RedisPredictiveCampaign.add(campaign.id, campaign.type)
    RedisStatus.set_state_changed_time(campaign.id, "On hold", session.id)
  end

  def calling_voter_preview_power(session, voter_id)
    enqueue_call_flow(CallerPusherJob, [session.id, "publish_calling_voter"])
    enqueue_call_flow(PreviewPowerDialJob, [session.id, voter_id])
  end

  def create_caller_identity(session_key)
    caller_identities.create(session_key: session_key, pin: CallerIdentity.create_uniq_pin)
  end

  private

  def assign_to_caller_group_campaign
    if caller_group_id_changed? && !caller_group_id.nil?
      self.campaign_id = CallerGroup.find(caller_group_id).campaign_id
    end
  end

  def restored_caller_has_campaign
    if active_change == [false, true] && !campaign.active
      errors.add(:base, 'The campaign this caller was assigned to has been deleted. Please assign the caller to a new campaign.')
    end
  end
end
