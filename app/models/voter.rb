require 'fiber'
class Voter < ActiveRecord::Base

  module Status
    NOTCALLED = "not called"
    RETRY = "retry"
  end

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
  validates_length_of :Phone, :minimum => 10, :unless => Proc.new{|voter| voter.Phone && voter.Phone.start_with?("+")}

  scope :existing_phone_in_campaign, lambda { |phone_number, campaign_id| where(:Phone => phone_number).where(:campaign_id => campaign_id) }

  scope :default_order, :order => 'LastName, FirstName, Phone'

  # scope :enabled, {:include => :voter_list, :conditions => {'voter_lists.enabled' => true}}
  scope :enabled, where(:enabled => true)

  scope :by_status, lambda { |status| where(:status => status) }
  scope :active, where(:active => true)
  scope :yet_to_call, enabled.where(:call_back => false).where('status not in (?) and priority is null', [CallAttempt::Status::INPROGRESS, CallAttempt::Status::RINGING, CallAttempt::Status::READY, CallAttempt::Status::SUCCESS, CallAttempt::Status::FAILED])
  scope :last_call_attempt_before_recycle_rate, lambda { |recycle_rate| where('last_call_attempt_time is null or last_call_attempt_time < ? ', recycle_rate.hours.ago) }
  scope :avialable_to_be_retried, lambda { |recycle_rate| where('last_call_attempt_time is not null and last_call_attempt_time < ? and status in (?)', recycle_rate.hours.ago,[CallAttempt::Status::BUSY,CallAttempt::Status::NOANSWER,CallAttempt::Status::HANGUP]) }
  scope :not_avialable_to_be_retried, lambda { |recycle_rate| where('last_call_attempt_time is not null and last_call_attempt_time > ? and status in (?)', recycle_rate.hours.ago,[CallAttempt::Status::BUSY,CallAttempt::Status::NOANSWER,CallAttempt::Status::HANGUP]) }
  scope :to_be_dialed, yet_to_call.order(:last_call_attempt_time)
  scope :randomly, order('rand()')
  scope :to_callback, where(:call_back => true)
  scope :scheduled, enabled.where(:scheduled_date => (10.minutes.ago..10.minutes.from_now)).where(:status => CallAttempt::Status::SCHEDULED)
  scope :limit, lambda { |n| {:limit => n} }
  scope :without, lambda { |numbers| where('Phone not in (?)', numbers << -1) }
  scope :not_skipped, where('skipped_time is null')
  scope :answered, where('result_date is not null')
  scope :answered_within, lambda { |from, to| where(:result_date => from.beginning_of_day..(to.end_of_day)) }
  scope :answered_within_timespan, lambda { |from, to| where(:result_date => from..to)}
  scope :last_call_attempt_within, lambda { |from, to| where(:last_call_attempt_time => (from..to)) }
  scope :call_attempts_within, lambda {|from, to| where('call_attempts.created_at' => (from..to)).includes('call_attempts')}
  scope :priority_voters, enabled.where(:priority => "1", :status => Voter::Status::NOTCALLED)


  before_validation :sanitize_phone

  cattr_reader :per_page
  @@per_page = 25

  def self.sanitize_phone(phonenumber)
    return phonenumber if phonenumber.blank?
    append = true if phonenumber.start_with?('+')
    sanitized = phonenumber.gsub(/[^0-9]/, "")
    append ? "+#{sanitized}" : sanitized
  end

  def sanitize_phone
    self.Phone = Voter.sanitize_phone(self.Phone) if self.Phone
  end

  def custom_fields
    account.custom_fields.map { |field| CustomVoterFieldValue.voter_fields(self, field).first.try(:value) }
  end

  def selected_fields(selection = nil)
    return [self.Phone] unless selection
    selection.select { |field| Voter.upload_fields.include?(field) }.map { |field| self.send(field) }
  end

  def selected_custom_fields(selection)
    selected_fields = []
    return selected_fields unless selection
    selection.each do |field|
      custom_voter_field = account.custom_voter_fields.find_by_name(field)
      unless custom_voter_field.nil?
        selected_fields << CustomVoterFieldValue.voter_fields(self, custom_voter_field).first.try(:value)
      end
    end
    selected_fields
  end


  def self.upload_fields
    ["Phone", "CustomID", "LastName", "FirstName", "MiddleName", "Suffix", "Email", "address", "city", "state","zip_code", "country"]
  end

  def self.remaining_voters_count_for(column_name, column_value)
    count(:conditions => "#{column_name} = #{column_value} AND active = 1 AND (status not in ('Call in progress','Ringing','Call ready to dial','Call completed with success.') or call_back=1)")
  end

  
  def dial_predictive_em(iter)
    call_attempt = new_call_attempt(self.campaign.type)
    twilio_lib = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    Rails.logger.info "#{call_attempt.id} - before call"
    http = twilio_lib.make_call(campaign, self, call_attempt)
    http.callback { 
      Rails.logger.info "#{call_attempt.id} - after call"    
      response = JSON.parse(http.response)  
      if response["status"] == 400
        handle_failed_call(call_attempt, self)
      else
        MonitorEvent.call_ringing(campaign)
        call_attempt.update_attributes(:sid => response["sid"])
      end
      iter.return(http)
       }
    http.errback { iter.return(http) }
  end

  def handle_failed_call(attempt, voter)
    attempt.update_attributes(status: CallAttempt::Status::FAILED, wrapup_time: Time.now)
    voter.update_attributes(status: CallAttempt::Status::FAILED)
  end


  def dial_predictive
    call_attempt = new_call_attempt(self.campaign.type)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    params = {'FallbackUrl' => TWILIO_ERROR, 'StatusCallback' => flow_call_url(call_attempt.call, host:  Settings.host, port:  Settings.port, event: 'call_ended'), 'Timeout' => campaign.use_recordings ? "20" : "15"}
    params.merge!({'IfMachine'=> 'Continue'}) if campaign.answering_machine_detect
    response = Twilio::Call.make(campaign.caller_id, self.Phone, flow_call_url(call_attempt.call, host:  Settings.host, port:  Settings.port, event:  'incoming_call'), params)
    if response["TwilioResponse"]["RestException"]
      call_attempt.update_attributes(status: CallAttempt::Status::FAILED, wrapup_time: Time.now)
      update_attributes(status: CallAttempt::Status::FAILED)
      Rails.logger.info "[dialer] Exception when attempted to call #{self.Phone} for campaign id:#{self.campaign_id}  Response: #{response["TwilioResponse"]["RestException"].inspect}"
      return
    end
    call_attempt.update_attributes(:sid => response["TwilioResponse"]["Call"]["Sid"])
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


  def selected_custom_voter_field_values
    select_custom_fields = campaign.script.try(:selected_custom_fields)
    custom_voter_field_values.try(:select) { |cvf| select_custom_fields.include?(cvf.custom_voter_field.name) } if select_custom_fields.present?
  end

  def info
    {:fields => self.attributes.reject { |k, v| (k == "created_at") ||(k == "updated_at") }, :custom_fields => {} }.try(:flatten)]}.merge!(campaign.script ? campaign.script.selected_fields_json : {})
  end

  def not_yet_called?(call_status)
    status==nil || status==call_status
  end

  def call_attempted_before?(time)
    last_call_attempt_time!=nil && last_call_attempt_time < (Time.now - time)
  end

  def self.to_be_called(campaign_id, active_list_ids, status, recycle_rate=3)
    voters = Voter.find_all_by_campaign_id_and_active(campaign_id, 1, :conditions=>"voter_list_id in (#{active_list_ids.join(",")})", :limit=>300, :order=>"rand()")
    voters.select { |voter| voter.not_yet_called?(status) || (voter.call_attempted_before?(recycle_rate.hours)) }
  end

  def self.just_called_voters_call_back(campaign_id, active_list_ids)
    uncalled = Voter.find_all_by_campaign_id_and_active_and_call_back(campaign_id, 1, 1, :conditions=>"voter_list_id in (#{active_list_ids.join(",")})")
    uncalled.select { |voter| voter.call_attempted_before?(10.minutes) }
  end

  def unanswered_questions
    campaign.script.questions.not_answered_by(self)
  end

  def question_not_answered
    unanswered_questions.first
  end

  def skip
    update_attributes(skipped_time: Time.now, status: 'not called')
  end

  def answer(question, response, recorded_by_caller = nil)
    possible_response = question.possible_responses.where(:keypad => response).first
    self.answer_recorded_by = recorded_by_caller
    return unless possible_response
    answers.create(question: question, possible_response: possible_response, campaign: Campaign.find(campaign_id), caller: recorded_by_caller.caller, call_attempt_id: last_call_attempt.id)
  end

  def answer_recorded_by
    @caller_session
  end

  def current_call_attempt
    answer_recorded_by.attempt_in_progress
  end

  def answer_recorded_by=(caller_session)
    @caller_session = caller_session
  end

  def persist_answers(questions, call_attempt)
     return if questions.nil?
     question_answers = JSON.parse(questions)
     retry_response = nil
     question_answers.try(:each_pair) do |question_id, answer_id|
       begin
         voters_response = PossibleResponse.find(answer_id)
         answers.create(possible_response: voters_response, question: Question.find(question_id), created_at: call_attempt.created_at, campaign: Campaign.find(campaign_id), caller: call_attempt.caller, call_attempt_id: call_attempt.id)
         retry_response ||= voters_response if voters_response.retry?
       rescue Exception => e
         Rails.logger.info "Persisting_Answers_Exception #{e.to_s}"
         Rails.logger.info "Voter #{self.inspect}"
       end
     end
     update_attributes(:status => Voter::Status::RETRY) if retry_response
   end

  def persist_notes(notes_json, call_attempt)
    return if notes_json.nil?
    notes = JSON.parse(notes_json)
    begin
      notes.try(:each_pair) do |note_id, note_res|
        note = Note.find(note_id)
        note_responses.create(response: note_res, note: Note.find(note_id), call_attempt_id: call_attempt.id, campaign_id: campaign_id)
      end
    rescue Exception => e
      Rails.logger.info "Persisting_Notes_Exception #{e.to_s}"
      Rails.logger.info "Voter #{self.inspect}"
    end
  end

  private

  def new_call_attempt(mode)
    call_attempt = self.call_attempts.create(campaign:  self.campaign, dialer_mode:  mode, status:  CallAttempt::Status::RINGING, call_start:  Time.now)
    update_attributes(:last_call_attempt => call_attempt, :last_call_attempt_time => Time.now, :status => CallAttempt::Status::RINGING)
    Call.create(call_attempt: call_attempt, all_states: "", state: 'initial')
    call_attempt
  end
end
