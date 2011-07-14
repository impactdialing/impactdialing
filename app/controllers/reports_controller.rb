class ReportsController < ApplicationController
  layout 'v2'

  def index
    @campaigns = Campaign.active
  end

  def usage
    @campaign = Campaign.find(params[:campaign_id])
    @minutes = @campaign.call_attempts.for_status(CallAttempt::Status::SUCCESS).inject(0) {|sum, ca| sum + ca.duration_rounded_up }
  end

end
