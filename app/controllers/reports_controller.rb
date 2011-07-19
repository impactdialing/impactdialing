class ReportsController < ClientController
  layout 'v2'

  def index
    @campaigns = @user.campaigns.robo.active
  end

  def usage
    @campaign = @user.campaigns.find(params[:campaign_id])
    @minutes = @campaign.call_attempts.for_status(CallAttempt::Status::SUCCESS).inject(0) { |sum, ca| sum + ca.minutes_used }
  end

  def dial_details
    @campaign = @user.campaigns.find(params[:campaign_id])
    respond_to do |format|
      format.csv do
        @csv = FasterCSV.generate do |csv|
          csv << ["Phone", "Status", @campaign.script.robo_recordings.collect{|rec| rec.name}].flatten
          @campaign.all_voters.each do |voter|
            attempt = voter.call_attempts.last
            if attempt
              csv  << [voter.Phone, voter.call_attempts.last.status, (attempt.call_responses.collect{|call_response| call_response.recording_response.response } if attempt.call_responses.size > 0) ].flatten
            else
              csv  << [voter.Phone, 'Not Dialed']
            end
          end
        end
        send_data @csv, :disposition => "attachment; filename=#{@campaign.name}_dial_details_report.csv"
      end
    end
  end

end
