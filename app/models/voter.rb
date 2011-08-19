class Voter < ActiveRecord::Base
  include ActionController::UrlWriter

  belongs_to :voter_list
  belongs_to :campaign
  has_many :families
  has_many :call_attempts
  has_many :custom_voter_field_values
  belongs_to :last_call_attempt, :class_name => "CallAttempt"
  belongs_to :user
  belongs_to :caller_session

  validates_presence_of :Phone
  validates_length_of :Phone, :minimum => 10

  scope :existing_phone_in_campaign, lambda { |phone_number, campaign_id|
    {:conditions => ['Phone = ? and campaign_id = ?', phone_number, campaign_id]}
  }

  default_scope :order => 'LastName, FirstName, Phone'
  scope :active, :conditions => ["active = ?", true]
  scope :to_be_dialed, :include => [:call_attempts], :conditions => ["(call_attempts.id is null and call_back is false) OR call_attempts.status IN (?)", CallAttempt::Status::ALL - [CallAttempt::Status::SUCCESS]]
  scope :randomly, :order => 'rand()'
  scope :to_callback, :conditions => ["call_back is true"]
  scope :scheduled, :conditions => {:scheduled_date => (10.minutes.ago..10.minutes.from_now), :status => CallAttempt::Status::SCHEDULED}
  scope :limit, lambda { |n| {:limit => n} }

  cattr_reader :per_page
  @@per_page = 25

  def self.sanitize_phone(phonenumber)
    phonenumber.gsub(/[^0-9]/, "") unless phonenumber.blank?
  end

  def before_validation
    self.Phone = Voter.sanitize_phone(self.Phone)
  end

  def self.upload_headers
    ["Phone", "ID", "LastName", "FirstName", "MiddleName", "Suffix", "Email"]
  end

  def self.upload_fields
    ["Phone", "CustomID", "LastName", "FirstName", "MiddleName", "Suffix", "Email"]
  end

  def dial
    message = "#{self.Phone} for campaign id:#{self.campaign_id}"
    logger.info "[dialer] Dialling #{message} "
    call_attempt = new_call_attempt
    callback_params = {:call_attempt_id => call_attempt.id, :host => Settings.host, :port => Settings.port}
    response = Twilio::Call.make(
        self.campaign.caller_id,
        self.Phone,
        twilio_callback_url(callback_params),
        'FallbackUrl' => twilio_report_error_url(callback_params),
        'StatusCallback' => twilio_call_ended_url(callback_params),
        'Timeout' => '20',
        'IfMachine' => 'Hangup'
    )

    if response["TwilioResponse"]["RestException"]
      logger.info "[dialer] Exception when attempted to call #{message}  Response: #{response["TwilioResponse"]["RestException"].inspect}"
      return false
    end
    logger.info "[dialer] Dialed #{message}. Response: #{response["TwilioResponse"].inspect}"
    call_attempt.update_attributes!(:sid => response["TwilioResponse"]["Call"]["Sid"])
    true
  end

  def dial_predictive
    call_attempt = new_call_attempt(self.campaign.predective_type)
    response = Twilio::Call.make(
        self.campaign.caller_id,
        self.Phone,
        connect_call_attempt_url(call_attempt, :host => Settings.host, :port =>Settings.port),
        'IfMachine' => self.campaign.use_recordings? ? 'Continue' : 'Hangup' ,
        'Timeout' => campaign.answer_detection_timeout || "20"
    )
    call_attempt.update_attributes(:status => CallAttempt::Status::INPROGRESS, :sid => response["TwilioResponse"]["Call"]["Sid"])
  end

  def conference(session)
    session.voter_in_progress = self
    session.save
    Twilio::TwiML::Response.new do |r|
      r.Dial :hangupOnStar => 'false' do |d|
        d.Conference "session#{session.id}", :wait_url => "", :beep => false, :endConferenceOnExit => true, :maxParticipants => 2
      end
    end.text
  end

  def apply_attribute(attribute, value)
    if self.has_attribute? attribute
      self[attribute] = value
    else
      custom_attribute = self.campaign.user.custom_voter_fields.find_by_name(attribute)
      custom_attribute ||= CustomVoterField.create(:name => attribute, :user => self.campaign.user) unless attribute.blank?
      CustomVoterFieldValue.create(:voter => self, :custom_voter_field => custom_attribute, :value => value)
    end
  end

  def get_attribute(attribute)
    return self[attribute] if self.has_attribute? attribute
    return unless CustomVoterField.find_by_name(attribute)
    fields = CustomVoterFieldValue.voter_fields(self, CustomVoterField.find_by_name(attribute))
    return if fields.empty?
    return fields.first.value
  end

  private
  def new_call_attempt(mode = 'robo')
    call_attempt = self.call_attempts.create(:campaign => self.campaign, :dialer_mode => mode, :status => CallAttempt::Status::INPROGRESS)
    self.update_attributes!(:last_call_attempt => call_attempt, :last_call_attempt_time => Time.now)
    call_attempt
  end
end
