module Client
  class ReportsController < ClientController
    before_filter :load_campaign, :except => [:index, :usage]

    def load_campaign
      @campaign = Campaign.find(params[:campaign_id])
    end

    def index
      @campaigns = params[:id].blank? ? account.campaigns.manual : Campaign.find(params[:id])
    end
    
    def dials
      from_date = Date.strptime(params[:from_date], "%m/%d/%Y") if params[:from_date]
      to_date = Date.strptime(params[:to_date], "%m/%d/%Y") if params[:to_date]
      @from_date = from_date || (@campaign.call_attempts.first.try(:created_at) || Time.now)
      @to_date = to_date || Time.now

      dialed_voters = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date)
      @total_voters = @campaign.all_voters
      if dialed_voters
        @answered = dialed_voters.by_status(CallAttempt::Status::ANSWERED).count
        @no_answer = dialed_voters.by_status(CallAttempt::Status::NOANSWER).count
        @busy_signal = dialed_voters.by_status(CallAttempt::Status::BUSY).count
        @ringing = dialed_voters.by_status(CallAttempt::Status::RINGING).count
        @abandoned = dialed_voters.by_status(CallAttempt::Status::ABANDONED).count
        @failed = dialed_voters.by_status(CallAttempt::Status::FAILED).count
        @voicemail = dialed_voters.by_status(CallAttempt::Status::VOICEMAIL).count
        @scheduled = dialed_voters.by_status(CallAttempt::Status::SCHEDULED).count
      end
      @total = ((@total_voters.count == 0) ? 1 : @total_voters.count)
      @ready_to_dial = params[:from_date] ? 0 : @total_voters.by_status(CallAttempt::Status::READY).count
      @not_dialed = not_dilaed_voters(params[:from_date])
    end

    def usage
      @campaign = @user.all_campaigns.find(params[:id])
      set_report_date_range

      all_call_attempts = @campaign.call_attempts.between(@from_date, @to_date + 1.day)
      @utilised_call_attempts_seconds = round_for_utilization(all_call_attempts.sum(:tDuration))
      @utilised_call_attempts_minutes = all_call_attempts.sum('ceil(tDuration/60)').to_i
      

      @caller_sessions_seconds = round_for_utilization(@campaign.caller_sessions.between(@from_date, @to_date + 1.day).sum(:tDuration))
      @caller_sessions_minutes = @campaign.caller_sessions.between(@from_date, @to_date + 1.day).sum('ceil(tDuration/60)').to_i


      @billable_call_attempts_seconds = round_for_utilization(all_call_attempts.without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum(:tDuration))
      @billable_call_attempts_minutes = all_call_attempts.without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum('ceil(tDuration/60)').to_i


      @billable_voicemail_seconds = round_for_utilization(all_call_attempts.with_status([CallAttempt::Status::VOICEMAIL]).sum(:tDuration))
      @billable_voicemail_minutes = all_call_attempts.with_status([CallAttempt::Status::VOICEMAIL]).sum('ceil(tDuration/60)').to_i
      

      @billable_abandoned_seconds = round_for_utilization(all_call_attempts.with_status([CallAttempt::Status::ABANDONED]).sum(:tDuration))
      @billable_abandoned_minutes = all_call_attempts.with_status([CallAttempt::Status::ABANDONED]).sum('ceil(tDuration/60)').to_i
    end
    
    def round_for_utilization(seconds)
      if seconds == 0
        0
      else
        (seconds/60).to_s + "." + (seconds % 60).to_s
      end
    end

    def download
      from_date = Date.strptime(params[:from_date], "%m/%d/%Y") if params[:from_date]
      to_date = Date.strptime(params[:to_date], "%m/%d/%Y") if params[:to_date]
      @from_date = from_date || (@campaign.call_attempts.first.try(:created_at) || Date.today)
      @to_date = to_date || (@campaign.call_attempts.last.try(:created_at) || Date.today)

      @voter_fields = VoterList::VOTER_DATA_COLUMNS
      @custom_voter_fields = @user.account.custom_voter_fields.collect{ |field| field.name}
      respond_to do |format|
        format.html
        #format.csv { send_data download_report, :type => "text/csv", :filename=>"#{@campaign.name}_report.csv", :disposition => 'attachment' }
        format.csv do
          Delayed::Job.enqueue ReportJob.new(@campaign, @user, params[:voter_fields], params[:custom_voter_fields], params[:download_all_voters], @from_date, @to_date)
          flash_message(:notice,I18n.t(:client_report_processing))
          redirect_to client_reports_path
        end
      end
    end

    def answer
      set_report_date_range
      @results = @campaign.answers_result(@from_date, @to_date)
    end

    private
    def download_report
      report = CSV.generate do |csv|
        selected_voter_fields = params[:voter_fields]
        selected_custom_voter_fields = params[:custom_voter_fields]
        csv << [selected_voter_fields ? selected_voter_fields : [], selected_custom_voter_fields ? selected_custom_voter_fields : [], "Caller", "Status", "Call start", "Call end", "Attempts", "Recording", @campaign.script.questions.collect { |q| q.text }, @campaign.script.notes.collect { |note| note.note }].flatten
        voters = params[:download_all_voters] ? @campaign.all_voters : @campaign.all_voters.answered_within(@from_date, @to_date)
        voters.try(:each) do |v|
          last_call_attempt = v.last_call_attempt
          
          notes, voter_custom_fields, answers, call_details = [], [], [], [last_call_attempt ? last_call_attempt.caller.try(:email) : '', v.status, last_call_attempt ? last_call_attempt.call_start.try(:in_time_zone, @campaign.time_zone) : '', last_call_attempt ? last_call_attempt.call_end.try(:in_time_zone, @campaign.time_zone) : '', v.call_attempts.size, last_call_attempt ? last_call_attempt.report_recording_url : ''].flatten
          voter_fields = selected_voter_fields ? [selected_voter_fields.try(:collect){|f| v.send(f)}].flatten : []
          custom_voter_field_objects = @campaign.account.custom_voter_fields.try(:select){|cf| selected_custom_voter_fields.try(:include?, cf.name)}
          custom_voter_field_objects.each { |cf| voter_custom_fields << v.custom_voter_field_values.for_field(cf).first.try(:value) }
          if last_call_attempt
            @campaign.script.questions.each { |q| answers << v.answers.for(q).first.try(:possible_response).try(:value) }
            @campaign.script.notes.each { |note| notes << v.note_responses.for(note).last.try(:response) }
            csv << [voter_fields, voter_custom_fields, call_details, answers, notes].flatten
          else
            csv << [voter_fields, voter_custom_fields, nil ,"Not Dialed"].flatten
          end
        end
      end
      report
    end
    
    def not_dilaed_voters(range_parameters)
      if range_parameters
        @total_voters.count - (@answered.to_i + @no_answer.to_i + @busy_signal.to_i + @ringing.to_i + @abandoned.to_i + @failed.to_i + @voicemail.to_i + @scheduled.to_i)
      else
        @total_voters.by_status(Voter::Status::NOTCALLED).count
      end
    end
  end
end
