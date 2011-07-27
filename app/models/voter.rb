class Voter < ActiveRecord::Base
  include ActionController::UrlWriter

  belongs_to :voter_list
  belongs_to :campaign
  has_many :families
  has_many :call_attempts
  belongs_to :last_call_attempt, :class_name => "CallAttempt"

  validates_presence_of :Phone
  validates_length_of :Phone, :minimum => 10
  validates_uniqueness_of :Phone, :scope => :voter_list_id

  named_scope :existing_phone_in_campaign, lambda { |phone_number, campaign_id|
    {:conditions => ['Phone = ? and campaign_id = ?', phone_number, campaign_id]}
  }

  default_scope :order => 'LastName, FirstName, Phone'
  named_scope :active, :conditions => ["active = ?", true]
  named_scope :to_be_dialed, :include => [:call_attempts], :conditions => ["(call_attempts.id is null and call_back is false) OR call_attempts.status IN (?)", CallAttempt::Status::ALL - [CallAttempt::Status::SUCCESS] ]
  named_scope :randomly, :order => 'rand()'
  named_scope :to_callback, :conditions => ["call_back is true"]

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

  def call_and_connect_to_session(session)
    require "hpricot"
    require "open-uri"
    campaign   = session.campaign
    self.status='Call attempt in progress'
    self.save
    t = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    if !campaign.caller_id.blank? && campaign.caller_id_verified
      caller_num=campaign.caller_id
    else
      caller_num=APP_NUMBER
    end
    c            = CallAttempt.new
    c.dialer_mode=campaign.predective_type
    c.voter_id   =self.id
    c.campaign_id=campaign.id
    c.status     ="Call ready to dial"
    c.save

    if campaign.predective_type=="preview"
      a=t.call("POST", "Calls", {'Timeout'=>"20", 'Caller' => caller_num, 'Called' => self.Phone, 'Url'=>"#{APP_URL}/callin/voterFindSession?campaign=#{campaign.id}&voter=#{self.id}&attempt=#{c.id}&selected_session=#{session.id}"})
    elsif campaign.use_answering
      if campaign.use_recordings
        a=t.call("POST", "Calls", {'Timeout'=>campaign.answer_detection_timeout, 'Caller' => caller_num, 'Called' => self.Phone, 'Url'=>"#{APP_URL}/callin/voterFindSession?campaign=#{campaign.id}&voter=#{self.id}&attempt=#{c.id}&selected_session=#{session.id}", 'IfMachine'=>'Continue'})
      else
        a=t.call("POST", "Calls", {'Timeout'=>campaign.answer_detection_timeout, 'Caller' => caller_num, 'Called' => self.Phone, 'Url'=>"#{APP_URL}/callin/voterFindSession?campaign=#{campaign.id}&voter=#{self.id}&attempt=#{c.id}&selected_session=#{session.id}", 'IfMachine'=>'Hangup'})
      end
    else
      a=t.call("POST", "Calls", {'Timeout'=>"15", 'Caller' => caller_num, 'Called' => self.Phone, 'Url'=>"#{APP_URL}/callin/voterFindSession?campaign=#{campaign.id}&voter=#{self.id}&attempt=#{c.id}&selected_session=#{session.id}"})
    end
    @doc    = Hpricot::XML(a)
    c.sid   =(@doc/"Sid").inner_html
    c.status="Call in progress"
    c.save
    self.last_call_attempt_id  =c.id
    self.last_call_attempt_time=Time.now
    self.save
  end

  def dial
    message = "#{self.Phone} for campaign id:#{self.campaign_id}"
    logger.info "[dialer] Dialling #{message} "
    call_attempt = new_call_attempt
    callback_params = {:call_attempt_id => call_attempt.id, :host => HOST, :port => PORT}
    response = Twilio::Call.make(
        self.campaign.caller_id,
        self.Phone,
        twilio_callback_url(callback_params),
        'FallbackUrl'    => twilio_report_error_url(callback_params),
        'StatusCallback' => twilio_call_ended_url(callback_params),
        'Timeout'        => '20',
        'IfMachine'      => 'Hangup'
    )

    if response["TwilioResponse"]["RestException"]
      logger.info "[dialer] Exception when attempted to call #{message}  Response: #{response["TwilioResponse"]["RestException"].inspect}"
      return false
    end
    logger.info "[dialer] Dialed #{message}. Response: #{response["TwilioResponse"].inspect}"
    call_attempt.update_attributes!(:sid => response["TwilioResponse"]["Call"]["Sid"])
    true
  end

  def apply_attribute(attribute,value)
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
    fields = CustomVoterFieldValue.voter_fields(self,CustomVoterField.find_by_name(attribute))
    return if fields.empty?
    return fields.first.value
  end

  private
  def new_call_attempt
    call_attempt = self.call_attempts.create(:campaign => self.campaign, :dialer_mode => 'robo', :status => CallAttempt::Status::INPROGRESS )
    self.update_attributes!(:last_call_attempt => call_attempt)
    call_attempt
  end
end
