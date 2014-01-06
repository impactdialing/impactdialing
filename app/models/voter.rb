require 'fiber'
class Voter < ActiveRecord::Base

  UPLOAD_FIELDS = ["phone", "custom_id", "last_name", "first_name", "middle_name", "suffix", "email", "address", "city", "state","zip_code", "country"]

  module Status
    NOTCALLED = "not called"
    RETRY = "retry"
  end

  include Rails.application.routes.url_helpers
  include CallAttempt::Status

  belongs_to :voter_list
  belongs_to :campaign
  belongs_to :account

  has_many :call_attempts
  has_many :custom_voter_field_values, autosave: true
  belongs_to :last_call_attempt, :class_name => "CallAttempt"
  belongs_to :caller_session
  has_many :answers
  has_many :note_responses

  validates_presence_of :phone

  validate :phone_validatation

  scope :by_campaign, ->(campaign) { where(campaign_id: campaign) }
  scope :existing_phone_in_campaign, lambda { |phone_number, campaign_id| where(:phone => phone_number).where(:campaign_id => campaign_id) }

  scope :default_order, :order => 'last_name, first_name, phone'

  # scope :enabled, {:include => :voter_list, :conditions => {'voter_lists.enabled' => true}}
  scope :enabled, where(:enabled => true)
  scope :disabled, where(:enabled => false)

  scope :by_status, lambda { |status| where(:status => status) }
  scope :active, where(:active => true)
  scope :yet_to_call, enabled.where(:call_back => false).where('status not in (?) and priority is null', [CallAttempt::Status::INPROGRESS, CallAttempt::Status::RINGING, CallAttempt::Status::READY, CallAttempt::Status::SUCCESS, CallAttempt::Status::FAILED])
  scope :last_call_attempt_before_recycle_rate, lambda { |recycle_rate| where('last_call_attempt_time is null or last_call_attempt_time < ? ', recycle_rate.hours.ago) }
  scope :avialable_to_be_retried, lambda { |recycle_rate| where('last_call_attempt_time is not null and last_call_attempt_time < ? and status in (?)', recycle_rate.hours.ago,[CallAttempt::Status::BUSY,CallAttempt::Status::NOANSWER,CallAttempt::Status::HANGUP, Voter::Status::RETRY]) }
  scope :not_avialable_to_be_retried, lambda { |recycle_rate| where('last_call_attempt_time is not null and last_call_attempt_time >= ? and status in (?)', recycle_rate.hours.ago,[CallAttempt::Status::BUSY,CallAttempt::Status::NOANSWER,CallAttempt::Status::HANGUP, Voter::Status::RETRY]) }
  scope :to_be_dialed, yet_to_call.order(:last_call_attempt_time)
  scope :randomly, order('rand()')
  scope :to_callback, where(:call_back => true)
  scope :scheduled, enabled.where(:scheduled_date => (10.minutes.ago..10.minutes.from_now)).where(:status => CallAttempt::Status::SCHEDULED)
  scope :limit, lambda { |n| {:limit => n} }
  scope :without, lambda { |numbers| where('phone not in (?)', numbers << -1) }
  scope :not_skipped, where('skipped_time is null')
  scope :answered, where('result_date is not null')
  scope :answered_within, lambda { |from, to| where(:result_date => from.beginning_of_day..(to.end_of_day)) }
  scope :answered_within_timespan, lambda { |from, to| where(:result_date => from..to)}
  scope :last_call_attempt_within, lambda { |from, to| where(:last_call_attempt_time => (from..to)) }
  scope :call_attempts_within, lambda {|from, to| where('call_attempts.created_at' => (from..to)).includes('call_attempts')}
  scope :priority_voters, enabled.where(:priority => "1", :status => Voter::Status::NOTCALLED)
  scope :in_progress_or_call_back, where(active: true).where("status NOT IN (?) OR call_back=1", [CallAttempt::Status::INPROGRESS, CallAttempt::Status::RINGING, CallAttempt::Status::READY, CallAttempt::Status::SUCCESS, CallAttempt::Status::FAILED])
  scope :remaining_voters_for_campaign, ->(campaign) { from('voters use index (index_voters_on_campaign_id_and_active_and_status_and_call_back)').
    in_progress_or_call_back.where(campaign_id: campaign) }
  scope :remaining_voters_for_voter_list, ->(voter_list) { in_progress_or_call_back.where(voter_list_id: voter_list) }

  scope :next_in_priority_or_scheduled_queues, lambda {|blocked_numbers|
    enabled.without(blocked_numbers).where([
      '(priority = ? AND status = ?) '+ # priority_voters
      'OR (scheduled_date BETWEEN ? AND ? AND status = ?)', # scheduled
      1, Voter::Status::NOTCALLED,
      10.minutes.ago, 10.minutes.from_now, CallAttempt::Status::SCHEDULED
    ])
  }

  scope :next_in_recycled_queue, lambda {|recycle_rate, blocked_numbers|
    enabled.without(blocked_numbers).
    last_call_attempt_before_recycle_rate(recycle_rate).
    to_be_dialed.order('id')
  }

  before_validation :sanitize_phone

  cattr_reader :per_page
  @@per_page = 25

  def self.next_recycled_voter(voters, recycle_rate, blocked_numbers, current_voter_id)
    query = voters.next_in_recycled_queue(recycle_rate, blocked_numbers)
    not_skipped = query.not_skipped.first

    if not_skipped.nil?
      if current_voter_id.present?
        voter = query.where(["id > ?", current_voter_id]).first
      end
      voter ||= query.first
    else
      if current_voter_id.nil?
        voter = not_skipped
      else
        voter = query.not_skipped.where(["id > ?", current_voter_id]).first
      end
    end

    return voter
  end

  def self.sanitize_phone(phonenumber)
    return phonenumber if phonenumber.blank?
    append = true if phonenumber.start_with?('+')
    sanitized = phonenumber.gsub(/[^0-9]/, "")
    append ? "+#{sanitized}" : sanitized
  end

  def sanitize_phone
    self.phone = Voter.sanitize_phone(self.phone) if self.phone
  end

  def self.phone_correct?(phone)
    phone && (phone.length >= 10 || phone.start_with?("+"))
  end

  def abandoned
    self.status = CallAttempt::Status::ABANDONED
    self.call_back = false
    self.caller_session = nil
    self.caller_id = nil
  end

  def end_answered_by_machine
    self.caller_session = nil
    self.status = campaign.use_recordings? ? CallAttempt::Status::VOICEMAIL : CallAttempt::Status::HANGUP
    self.call_back = false
  end

  def end_unanswered_call(call_status)
    self.status = CallAttempt::Status::MAP[call_status]
    self.call_back = false
  end


  def disconnect_call(caller_id)
    self.status = CallAttempt::Status::SUCCESS
    self.caller_session = nil
    self.caller_id = caller_id
  end

  def schedule_for_later(date)
    scheduled_date = DateTime.strptime(date, "%m/%d/%Y %H:%M").to_time
    self.status = Status::SCHEDULED
    self.scheduled_date = scheduled_date
    self.call_back = true
  end

  def self.upload_fields
    ["phone", "custom_id", "last_name", "first_name", "middle_name", "suffix", "email", "address", "city", "state","zip_code", "country"]
  end

  def get_attribute(attribute)
    return self[attribute] if self.has_attribute? attribute
    return unless CustomVoterField.find_by_name(attribute)
    fields = CustomVoterFieldValue.voter_fields(self, CustomVoterField.find_by_name(attribute))
    return if fields.empty?
    return fields.first.value
  end

  def blocked?
    account.blocked_numbers.for_campaign(campaign).map(&:number).include?(self.phone)
  end

  def selected_custom_voter_field_values
    select_custom_fields = campaign.script.try(:selected_custom_fields)
    custom_voter_field_values.try(:select) { |cvf| select_custom_fields.include?(cvf.custom_voter_field.name) } if select_custom_fields.present?
  end

  def info
    {:fields => self.attributes.reject { |k, v| (k == "created_at") ||(k == "updated_at") }, :custom_fields => Hash[*self.selected_custom_voter_field_values.try(:collect) { |cvfv| [cvfv.custom_voter_field.name, cvfv.value] }.try(:flatten)]}.merge!(campaign.script ? campaign.script.selected_fields_json : {})
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
    Answer.new(question: question, possible_response: possible_response, campaign: Campaign.find(campaign_id), caller: recorded_by_caller.caller, call_attempt_id: last_call_attempt.id, voter_id: self.id)
  end

  def answer_recorded_by
    @caller_session
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

  def phone_validatation
    errors.add(:phone, 'should be at least 10 digits') unless Voter.phone_correct?(self.phone)
  end

end
