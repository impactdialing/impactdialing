require Rails.root.join("jobs/report_download_job")
module Api
  class ReportsController < ApiController
    include TimeZoneHelper
    
    def validate_date_range(from_date, to_date, download_all_voters)
      unless to_boolean(download_all_voters)
        if from_date.nil? || to_date.nil?
          render_json_response({status: 'error', code: '400', message: "From and To date cannot be nil"})
          return false          
        end
        begin
          @from_date = Date.strptime(from_date, '%m/%d/%Y %H:%M')
          @to_date = Date.strptime(to_date, '%m/%d/%Y %H:%M')
        rescue ArgumentError => err
          render_json_response({status: 'error', code: '400', message: err.to_s + " Use mm/dd/yyyy HH:MM format"})
          return false
        end      
      end
      return true      
    end
    
    
    def validate_params
      validate_campaign(params[:campaign_id]) && validate_account(params[:account_id]) && validate_campaign_belongs_to_account(params[:campaign_id], params[:account_id]) && validate_email_belongs_to_account(params[:account_id], params[:email]) && validate_date_range(params[:from_date], params[:to_date], params[:download_all_voters])      
    end
    
    def create
      return unless validate_params
      @campaign = Campaign.find(params[:campaign_id])
      user = User.find_by_email(params[:email])
      @from_date, @to_date = set_date_range_with_time(@campaign, params[:from_date], params[:to_date]) unless to_boolean(params[:download_all_voters])
      Resque.enqueue(ReportDownloadJob, @campaign.id, user.id, params[:voter_fields], params[:custom_voter_fields], to_boolean(params[:download_all_voters]),params[:lead_dial], @from_date, @to_date, params[:callback_url], "api")
      render_json_response({status: 'ok', code: '200' , message: "Response will be sent to the callback url once the report is ready for download."})
    end        
  end
end  