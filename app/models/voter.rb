class Voter < ActiveRecord::Base
  include Rails.application.routes.url_helpers

  belongs_to :voter_list
  belongs_to :campaign
  belongs_to :account
  has_many :families
  has_many :call_attempts
  has_many :custom_voter_field_values
  belongs_to :last_call_attempt, :class_name => "CallAttempt"
  belongs_to :caller_session
  has_many :answers

  validates_presence_of :Phone
  validates_length_of :Phone, :minimum => 10

  scope :existing_phone_in_campaign, lambda { |phone_number, campaign_id|
    {:conditions => ['Phone = ? and campaign_id = ?', phone_number, campaign_id]}
  }

  scope :default_order, :order => 'LastName, FirstName, Phone'

  scope :by_status, lambda { |status| where(:status => status) }
  scope :active, where(:active => true)
  scope :to_be_dialed, :conditions => ["call_back is false AND status != (?)", CallAttempt::Status::SUCCESS]
  scope :randomly, :order => 'rand()'
  scope :to_callback, where(:call_back => true)
  scope :scheduled, :conditions => {:scheduled_date => (10.minutes.ago..10.minutes.from_now), :status => CallAttempt::Status::SCHEDULED}
  scope :limit, lambda { |n| {:limit => n} }
  scope :without, lambda { |numbers| where('Phone not in (?)', numbers) }

  before_validation :sanitize_phone

  cattr_reader :per_page
  @@per_page = 25

  def self.sanitize_phone(phonenumber)
    phonenumber.gsub(/[^0-9]/, "") unless phonenumber.blank?
  end

  def sanitize_phone
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
    campaign = session.campaign
    self.status='Call attempt in progress'
    self.save
    t = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    if !campaign.caller_id.blank? && campaign.caller_id_verified
      caller_num=campaign.caller_id
    else
      caller_num=APP_NUMBER
    end
    c = CallAttempt.new
    c.dialer_mode=campaign.predictive_type
    c.voter_id =self.id
    c.campaign_id=campaign.id
    c.status ="Call ready to dial"
    c.save

    if campaign.predictive_type=="preview"
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
    @doc = Hpricot::XML(a)
    c.sid =(@doc/"Sid").inner_html
    c.status="Call in progress"
    c.save
    self.last_call_attempt_id =c.id
    self.last_call_attempt_time=Time.now
    self.save
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
    # Thread.new {
      @client = Twilio::REST::Client.new TWILIO_ACCOUNT, TWILIO_AUTH
      call_attempt = new_call_attempt(self.campaign.predictive_type)

      @call = @client.account.calls.create(
        :from => campaign.caller_id,
        :to => self.Phone,
        :url => connect_call_attempt_url(call_attempt, :host => Settings.host, :port =>Settings.port),
        'StatusCallback' => end_call_attempt_url(call_attempt, :host => Settings.host, :port => Settings.port) ,
        'IfMachine' => self.campaign.use_recordings? ? 'Continue' : 'Hangup' ,
        'Timeout' => campaign.answer_detection_timeout || 20
      )
      call_attempt.update_attributes(:status => CallAttempt::Status::INPROGRESS, :sid => @call.sid)
      # call_attempt.sid
    # }
  end


  def conference(session)
    session.update_attributes(:voter_in_progress => self)
  end

  def apply_attribute(attribute, value)
    if self.has_attribute? attribute
      self[attribute] = value
    else
      custom_attribute = self.campaign.account.custom_voter_fields.find_by_name(attribute)
      custom_attribute ||= CustomVoterField.create(:name => attribute, :account => self.campaign.account) unless attribute.blank?
      self.custom_voter_field_values.create(:voter => self, :custom_voter_field => custom_attribute, :value => value)
    end
  end

  def get_attribute(attribute)
    return self[attribute] if self.has_attribute? attribute
    return unless CustomVoterField.find_by_name(attribute)
    fields = CustomVoterFieldValue.voter_fields(self, CustomVoterField.find_by_name(attribute))
    return if fields.empty?
    return fields.first.value
  end

  def blocked?
    account.blocked_numbers.for_campaign(campaign).map(&:number).include?(self.Phone)
  end

  def info
    {:fields => self.attributes.reject{|k,v| (k == "created_at") ||(k == "updated_at")}, :custom_fields => Hash[*self.custom_voter_field_values.collect{|cvfv| [cvfv.custom_voter_field.name, cvfv.value]}.flatten] }
  end

  module Status
    NOTCALLED = "not called"
  end

  private
  def new_call_attempt(mode = 'robo')
    call_attempt = self.call_attempts.create(:campaign => self.campaign, :dialer_mode => mode, :status => CallAttempt::Status::INPROGRESS)
    self.update_attributes!(:last_call_attempt => call_attempt, :last_call_attempt_time => Time.now)
    call_attempt
  end
end
