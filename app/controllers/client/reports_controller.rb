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

      @voter_fields = ["CustomID","FirstName","MiddleName","LastName","Suffix","Age","Gender","Phone","Email"]
      @custom_voter_fields = @user.account.custom_voter_fields.collect{ |field| field.name}
      respond_to do |format|
        format.html
        format.csv { send_data download_report, :type => "text/csv", :filename=>"#{@campaign.name}_report.csv", :disposition => 'attachment' }
      end
    end

    def answer
      set_report_date_range
      @results = @campaign.answers_result(@from_date, @to_date)
    end

    private
    def download_report
      report = CSV.generate do |csv|
        #selected_voter_fields = params[:voter_fields]
        #selected_custom_voter_fields = params[:custom_voter_fields]
        csv << [params[:voter_fields], "Caller", "Status", "Call start", "Call end", "Attempts", "Recording", params[:custom_voter_fields], @campaign.script.questions.collect { |q| q.text }, @campaign.script.notes.collect { |note| note.note }].flatten
        
        @campaign.all_voters.answered_within(@from_date, @to_date).each do |v|
        #@campaign.all_voters.each do |v|
          last_call_attempt = v.last_call_attempt
          notes, custom_fields, answers, voter_details = [], [], [], [selected_voter_fields.try(:collect){|f| v.send(f)}, last_call_attempt ? last_call_attempt.caller.name : '', v.status, last_call_attempt ? last_call_attempt.call_start : '', last_call_attempt ? last_call_attempt.call_end : '', v.call_attempts.size, last_call_attempt ? last_call_attempt.report_recording_url : ''].flatten

          custom_voter_field_objects = @campaign.account.custom_voter_fields.try(:select){|cf| selected_custom_voter_fields.try(:include?, " "+cf.name)}
          # selected_custom_voter_fields.try(:each){|cf| custom_fields << v.custom_voter_field_values.for_field(cf).first.try(:value)}
          custom_voter_field_objects.each { |cf| custom_fields << v.custom_voter_field_values.for_field(cf).first.try(:value) }
          
          @campaign.script.questions.each { |q| answers << v.answers.for(q).first.try(:possible_response).try(:value) }
          @campaign.script.notes.each { |note| notes << v.note_responses.for(note).last.try(:response) }
          csv << [voter_details, custom_fields, answers, notes].flatten
        end
      end
      report
    end
  end
end
