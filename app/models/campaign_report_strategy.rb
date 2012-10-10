class CampaignReportStrategy
  
  module Mode
    PER_LEAD = "lead"
    PER_DIAL = "dial"
  end
  
  module AttemptStatus
    ANSWERED = "Answered"
    ABANDONED = "Abandoned"
    FAILED = "Failed"
    BUSY = "Busy"
    NOANSWER = 'No answer'
    ANSWERING_MACHINE = "Answering machine"
    ANSWERING_MACHINE_MESSAGE = "Voicemail left"
    SCHEDULED = 'Answered'
    NOT_DIALED = "Not Dialed"
  end
  
  def self.map_status(status)
    statuses = {CallAttempt::Status::SUCCESS => AttemptStatus::ANSWERED, Voter::Status::RETRY => AttemptStatus::ANSWERED, 
      Voter::Status::NOTCALLED => AttemptStatus::NOT_DIALED, CallAttempt::Status::NOANSWER => AttemptStatus::NOANSWER, 
      CallAttempt::Status::ABANDONED => AttemptStatus::ABANDONED, CallAttempt::Status::BUSY => AttemptStatus::BUSY,
      CallAttempt::Status::FAILED => AttemptStatus::FAILED, CallAttempt::Status::HANGUP => AttemptStatus::ANSWERING_MACHINE,
      CallAttempt::Status::SCHEDULED => AttemptStatus::ANSWERED, CallAttempt::Status::VOICEMAIL => AttemptStatus::ANSWERING_MACHINE_MESSAGE}
      statuses[status] || status
  end
  
  
  def initialize(campaign, csv, download_all_voters, mode, selected_voter_fields, selected_custom_voter_fields, from_date, to_date)
    @campaign = campaign
    @download_all_voters = download_all_voters ? ("download_all_voters_" + mode) : ("download_for_date_range_" + mode)
    @mode = mode
    @csv = csv
    @selected_voter_fields = selected_voter_fields
    @selected_custom_voter_fields = selected_custom_voter_fields
    @question_ids = Answer.question_ids(@campaign.id)
    @note_ids = NoteResponse.note_ids(@campaign.id)           
    @from_date = from_date
    @to_date = to_date
  end
  
  def construct_csv
    @csv << csv_header    
    self.send(@download_all_voters)
    @csv
  end
  
  def csv_for(voter)
    voter_fields = VoterFieldsLogic.selected_fields(voter, @selected_voter_fields.try(:compact))
    custom_fields = VoterFieldsLogic.selected_custom_fields(voter, @selected_custom_voter_fields)
    [*voter_fields, *custom_fields, [nil, "Not Dialed","","","","", [], []]]
  end
  
  def call_attempt_info(call_attempt)
    if @mode == CampaignReportStrategy::Mode::PER_LEAD
      [caller_name(call_attempt), CampaignReportStrategy.map_status(call_attempt['status']), time_dialed(call_attempt),
       time_answered(call_attempt), time_ended(call_attempt), number_of_attempts(call_attempt['voter_id']),
       CallAttempt.report_recording_url(call_attempt['recording_url'])].flatten
    else
      [caller_name(call_attempt), CampaignReportStrategy.map_status(call_attempt['status']), time_dialed(call_attempt),
       time_answered(call_attempt), time_ended(call_attempt), CallAttempt.report_recording_url(call_attempt['recording_url'])].flatten
    end
     
  end
  
  def caller_name(call_attempt)
    Caller.where(id: call_attempt['caller_id']).first.try(:known_as)
  end
  
  def time_dialed(call_attempt)
    call_attempt['call_start'].try(:in_time_zone, @campaign.time_zone)
  end
  
  def time_answered(call_attempt)
    call_attempt['connecttime'].try(:in_time_zone, @campaign.time_zone)
  end
  
  def time_ended(call_attempt)
    call_attempt['call_end'].try(:in_time_zone, @campaign.time_zone)
  end
  
  
  def number_of_attempts(voter)
    CallAttempt.where(voter_id: voter).count
  end
  
  
  def answers(call_attempt)
    call_attempt.answers.for_questions(@question_ids).order('question_id')
  end
  
  def note_responses(call_attempt)
    call_attempt.note_responses.for_notes(@note_ids).order('note_id')
  end
  
end
