module Client
  class ReportsController < ClientController
    before_filter :load_campaign, :except => [:index, :usage]

    def load_campaign
      @campaign = Campaign.find(params[:campaign_id])
    end

    def index
      @campaigns = params[:id].blank? ? account.campaigns.manual : Campaign.find(params[:id])
    end

    def usage
      @campaign = @user.all_campaigns.find(params[:id])
      set_report_date_range

      all_call_attempts = @campaign.call_attempts.between(@from_date, @to_date + 1.day)

      @utilised_call_attempts_seconds = all_call_attempts.sum(:tDuration)
      @utilised_call_attempts_minutes = all_call_attempts.sum('ceil(tDuration/60)').to_i

      @caller_sessions_seconds = @campaign.caller_sessions.between(@from_date, @to_date + 1.day).sum(:tDuration)
      @caller_sessions_minutes = @campaign.caller_sessions.between(@from_date, @to_date + 1.day).sum('ceil(tDuration/60)').to_i

      @billable_call_attempts_seconds = all_call_attempts.without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum(:tDuration)
      @billable_call_attempts_minutes = all_call_attempts.without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum('ceil(tDuration/60)').to_i

      @billable_voicemail_seconds = all_call_attempts.with_status([CallAttempt::Status::VOICEMAIL]).sum(:tDuration)
      @billable_voicemail_minutes = all_call_attempts.with_status([CallAttempt::Status::VOICEMAIL]).sum('ceil(tDuration/60)').to_i

      @billable_abandoned_seconds = all_call_attempts.with_status([CallAttempt::Status::ABANDONED]).sum(:tDuration)
      @billable_abandoned_minutes = all_call_attempts.with_status([CallAttempt::Status::ABANDONED]).sum('ceil(tDuration/60)').to_i
    end

    def download
      from_date = Date.strptime(params[:from_date], "%m/%d/%Y") if params[:from_date]
      to_date = Date.strptime(params[:to_date], "%m/%d/%Y") if params[:to_date]
      @from_date = from_date || (@campaign.call_attempts.first.try(:created_at) || Date.today)
      @to_date = to_date || (@campaign.call_attempts.last.try(:created_at) || Date.today)
      respond_to do |format|
        format.html
        format.csv { send_data download_report, :type => "text/csv", :filename=>"#{@campaign.name}_report.csv", :disposition => 'attachment' }
      end
    end

    private
    def download_report
      report = CSV.generate do |csv|
        csv << ["_ID", "LastName", "FirstName", "MiddleName", "Suffix", "Phone", "Caller", "Status", "Call start", "Call end", "Attempts", @campaign.account.custom_voter_fields.collect { |cf| cf.name }, @campaign.script.questions.collect { |q| q.text }, @campaign.script.notes.collect { |note| note.note }].flatten
        @campaign.all_voters.answered_within(@from_date, @to_date).each do |v|
          notes, custom_fields, answers, voter_details = [], [], [], [v.CustomID, v.LastName, v.FirstName, v.MiddleName, v.Suffix, v.Phone, v.last_call_attempt.caller.name, v.status, v.last_call_attempt.call_start, v.last_call_attempt.call_end, v.call_attempts.size]
          @campaign.account.custom_voter_fields.each { |cf| custom_fields << v.custom_voter_field_values.for_field(cf).first.try(:value) }
          @campaign.script.questions.each { |q| answers << v.answers.for(q).first.try(:possible_response).try(:value) }
          @campaign.script.notes.each { |note| notes << v.note_responses.for(note).last.try(:response) }
          csv << [voter_details, custom_fields, answers, notes].flatten
        end
      end
      report
    end

  end
end
