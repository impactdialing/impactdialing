class CampaignReportStrategy

private
  def message_left_text(recording_id, recording_delivered_manually)
    return "No" if recording_id.nil? or recording_delivered_manually.nil?

    # argh, something magical this way lies...
    # occasionally FixNum(0) or String(0) is converted
    # to FalseClass and fails w/ NME when normalizing w/ .to_i
    # e.g. `call_attempt['recording_delivered_manually'].to_i > 0`
    #
    # exception notifcation received from production w/ NME on .to_i July 1, 2014
    manual_delivery = [1, '1', true, 'true'].include?(recording_delivered_manually)

    if manual_delivery
      return "Yes: caller dropped"
    else
      return "Yes: automatically"
    end
  end

public
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
    @replica_connection = OctopusConnection.connection(OctopusConnection.dynamic_shard(:read_slave1, :read_slave2))
  end

  def construct_csv
    @csv << csv_header
    self.send(@download_all_voters)
    @csv
  end

  def call_attempt_info(call_attempt, caller_names, attempt_numbers, transfer_attempt={}, voter={}, voicemail_history={})
    out = [
      caller_names[call_attempt['caller_id']],
      CampaignReportStrategy.map_status(call_attempt['status']),
      time_dialed(call_attempt),
      time_answered(call_attempt),
      time_ended(call_attempt),
      call_time_duration(call_attempt),
      transfer_times(transfer_attempt, 'tStartTime'),
      transfer_times(transfer_attempt, 'tEndTime'),
      transfer_times(transfer_attempt, 'tDuration')
    ]
    
    if @mode == CampaignReportStrategy::Mode::PER_LEAD
      out << attempt_numbers[call_attempt['household_id']][:cnt]
    end

    out << voicemail_history[call_attempt['household_id']][:message_left_text]
    out << CallAttempt.report_recording_url(call_attempt['recording_url'])
    out.flatten
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

  def call_time_duration(call_attempt)
    call_attempt['tDuration']
  end

  def transfer_times(transfer_attempt, attribute)
    data             = 'N/A'
    if transfer_attempt.present?
      if transfer_attempt[attribute].present?
        data = transfer_attempt[attribute]

        case attribute
        when /t(End|Start)Time/
          data = data.try(:in_time_zone, @campaign.time_zone)
        when 'tDuration'
          data = (data.to_f / 60).ceil
        end
      end
    end
    return data
  end

  def answers(call_attempt)
    call_attempt.answers.for_questions(@question_ids).order('question_id')
  end

  def note_responses(call_attempt)
    call_attempt.note_responses.for_notes(@note_ids).order('note_id')
  end

end
