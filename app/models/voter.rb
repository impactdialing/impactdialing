class Voter < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallAttempt::Status

  belongs_to :voter_list
  belongs_to :campaign
  belongs_to :account
  has_many :families
  has_many :call_attempts
  has_many :custom_voter_field_values
  belongs_to :last_call_attempt, :class_name => "CallAttempt"
  belongs_to :caller_session
  has_many :answers
  has_many :note_responses

  validates_presence_of :Phone
  validates_length_of :Phone, :minimum => 10

  scope :existing_phone_in_campaign, lambda { |phone_number, campaign_id|
    {:conditions => ['Phone = ? and campaign_id = ?', phone_number, campaign_id]}
  }

  scope :default_order, :order => 'LastName, FirstName, Phone'

  scope :by_status, lambda { |status| where(:status => status) }
  scope :active, where(:active => true)
  scope :yet_to_call, where("call_back is false AND status != (?)", CallAttempt::Status::SUCCESS)
  scope :to_be_dialed, yet_to_call.order("ifnull(last_call_attempt_time, '#{Time.at(0)}') ASC")
  scope :randomly, :order => 'rand()'
  scope :to_callback, where(:call_back => true)
  scope :scheduled, :conditions => {:scheduled_date => (10.minutes.ago..10.minutes.from_now), :status => CallAttempt::Status::SCHEDULED}
  scope :limit, lambda { |n| {:limit => n} }
  scope :without, lambda { |numbers| where('Phone not in (?)', numbers) }
  scope :answered, where('result_date is not null')
  scope :answered_within, lambda { |from, to| where(" result_date between '#{from}' and '#{to + 1.day}' ") }

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


  def dial
    return false if status == Voter::SUCCESS
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
    @client = Twilio::REST::Client.new TWILIO_ACCOUNT, TWILIO_ACCOUNT_AUTH    
    caller_session = campaign.caller_sessions.available.first
    DIALER_LOGGER.info "connect to _caller #{caller_session.inspect} , #{campaign.predictive_type}"
    unless caller_session.nil?      
      DIALER_LOGGER.info "Pushing data for #{info.inspect}"
      call_attempt = new_call_attempt(self.campaign.predictive_type)
      call_attempt.update_attributes(caller_session: caller_session)

      @call = @client.account.calls.create(
          :from => campaign.caller_id,
          :to => self.Phone,
          :url => connect_call_attempt_url(call_attempt, :host => Settings.host, :port =>Settings.port),
          'StatusCallback' => end_call_attempt_url(call_attempt, :host => Settings.host, :port => Settings.port),
          'IfMachine' => self.campaign.use_recordings? ? 'Continue' : 'Hangup',
          'Timeout' => campaign.answer_detection_timeout || 20
      )
      call_attempt.update_attributes(:status => CallAttempt::Status::INPROGRESS, :sid => @call.sid)
    end
    # call_attempt.sid
    # }
  end


  def conference(session)
    session.update_attributes(:voter_in_progress => self)
  end

  def apply_attribute(attribute, value)
    if self.has_attribute? attribute
      self.update_attributes(attribute => value)
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

  def capture(response)
    update_attribute(:result_date, Time.now)
    capture_answers(response["question"])
    capture_notes(response['notes'])
  end

  def info
    {:fields => self.attributes.reject { |k, v| (k == "created_at") ||(k == "updated_at") }, :custom_fields => Hash[*self.custom_voter_field_values.collect { |cvfv| [cvfv.custom_voter_field.name, cvfv.value] }.flatten]}
  end

  def not_yet_called?(call_status)
    status==nil || status==call_status
  end

  def call_attempted__before?(time)
    call_back? && last_call_attempt_time!=nil && last_call_attempt_time < (Time.now - time)
  end

  def self.to_be_called(campaign_id, active_list_ids, status)
    voters = Voter.find_all_by_campaign_id_and_active(campaign_id, 1, :conditions=>"voter_list_id in (#{active_list_ids.join(",")})", :limit=>300, :order=>"rand()")
    voters.select {|voter| voter.not_yet_called?(status) || (voter.call_attempted__before?(3.hours))}
  end

  def self.just_called_voters_call_back(campaign_id, active_list_ids)
    uncalled = Voter.find_all_by_campaign_id_and_active_and_call_back(campaign_id, 1, 1, :conditions=>"voter_list_id in (#{active_list_ids.join(",")})")
    uncalled.select { |voter| voter.call_attempted__before?(10.minutes) }
  end

  module Status
    NOTCALLED = "not called"
    RETRY = "retry"
  end

  def unresponded_questions
    unresponded = []
    campaign.script.questions.each do |question|
      unresponded << question if answers.for(question).blank?
    end
    unresponded
  end

  private
  def new_call_attempt(mode = 'robo')
    call_attempt = self.call_attempts.create(:campaign => self.campaign, :dialer_mode => mode, :status => CallAttempt::Status::INPROGRESS)
    self.update_attributes!(:last_call_attempt => call_attempt, :last_call_attempt_time => Time.now)
    call_attempt
  end

  def capture_answers(questions)
    retry_response = nil
    questions.try(:each_pair) do |question_id, answer_id|
      voters_response = PossibleResponse.find(answer_id)
      current_response = answers.find_by_question_id(question_id)
      current_response ? current_response.update_attributes(:possible_response => voters_response) : answers.create(:possible_response => voters_response, :question => Question.find(question_id))
      retry_response ||= voters_response if voters_response.retry?
    end
    update_attributes(:status => Voter::Status::RETRY) if retry_response
  end

  def capture_notes(notes)
    notes.try(:each_pair) do |note_id, note_res|
      note = Note.find(note_id)
      note_response = note_responses.find_by_note_id(note_id)
      note_response ? note_response.update_attributes(response: note_res) : note_responses.create(response: note_res, note: Note.find(note_id))
    end
  end



end
