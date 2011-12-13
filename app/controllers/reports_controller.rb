class ReportsController < ClientController
  layout 'v2'

  def index
    @campaigns = account.campaigns.robo.active
  end

  def usage
    @campaign = account.campaigns.find(params[:campaign_id])
    @minutes = @campaign.call_attempts.for_status(CallAttempt::Status::SUCCESS).inject(0) { |sum, ca| sum + ca.minutes_used }
  end
  
  def dial_details
    @campaign = account.campaigns.find(params[:id])
    from_date = Date.strptime(params[:from_date], "%m/%d/%Y") if params[:from_date]
    to_date = Date.strptime(params[:to_date], "%m/%d/%Y") if params[:to_date]
    @from_date = from_date || (@campaign.call_attempts.first.try(:created_at) || Date.today)
    @to_date = to_date || (@campaign.call_attempts.last.try(:created_at) || Date.today)

    @voter_fields = VoterList::VOTER_DATA_COLUMNS
    @custom_voter_fields = @user.account.custom_voter_fields.collect{ |field| field.name}
    respond_to do |format|
      format.html
      format.csv { send_data download_csv, :type => "text/csv", :filename=>"#{@campaign.name}_report.csv", :disposition => 'attachment' }
    end
  end
  
  private
  
  def download_csv
    selected_voter_fields = params[:voter_fields]
    selected_custom_voter_fields = params[:custom_voter_fields]
    @csv = CSV.generate do |csv|
      csv << [selected_voter_fields ? selected_voter_fields : [], selected_custom_voter_fields ? selected_custom_voter_fields : [], "Status", @campaign.script.robo_recordings.collect{|rec| rec.name}].flatten
      @campaign.all_voters.answered_within(@from_date, @to_date).each do |voter| 

        voter_fields = selected_voter_fields ? [selected_voter_fields.try(:collect){|f| voter.send(f)}].flatten : []
        voter_custom_fields = []
        custom_voter_field_objects = @campaign.account.custom_voter_fields.try(:select){|cf| selected_custom_voter_fields.try(:include?, cf.name)}
        custom_voter_field_objects.each { |cf| voter_custom_fields << voter.custom_voter_field_values.for_field(cf).first.try(:value) }
        
        attempt = voter.call_attempts.last
        if attempt
          csv  << [voter_fields, voter_custom_fields, voter.call_attempts.last.status, (attempt.call_responses.collect{|call_response| call_response.recording_response.try(:response) } if attempt.call_responses.size > 0) ].flatten
        else
          csv  << [voter_fields, voter_custom_fields, 'Not Dialed'].flatten
        end
      end
    end
    @csv
  end
end
