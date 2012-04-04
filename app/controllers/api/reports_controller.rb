module Api
  class ReportsController < ApiController
    
    def validate_date_range(from_date, to_date, download_all_voters)
      unless to_boolean(download_all_voters)
        if from_date.nil? || to_date.nil?
          render_json_response({status: 'error', code: '400', message: "From and To date cannot be nil"})
          return false          
        end
        begin
          @from_date = Date.strptime(from_date, '%m/%d/%Y')
          @to_date = Date.strptime(to_date, '%m/%d/%Y')
        rescue ArgumentError => err
          render_json_response({status: 'error', code: '400', message: err.to_s + " Use mm/dd/yyyy format"})
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
      set_date_range
      Delayed::Job.enqueue ReportJob.new(@campaign, user, params[:voter_fields], params[:custom_voter_fields], to_boolean(params[:download_all_voters]), @from_date, @to_date, params[:callback_url], "api")
      render_json_response({status: 'ok', code: '200' , message: "An email will be sent to #{params[:email]} with the status of the report download"})
    end
    
    def set_date_range
      time_zone = ActiveSupport::TimeZone.new(@campaign.time_zone || "UTC")
      from_date = Time.strptime("#{params[:from_date]} #{time_zone.formatted_offset}", "%m/%d/%Y %:z") if params[:from_date]
      to_date = Time.strptime("#{params[:to_date]} #{time_zone.formatted_offset}", "%m/%d/%Y %:z") if params[:to_date]
      @from_date = (from_date || @campaign.call_attempts.first.try(:created_at) || Time.now).in_time_zone(time_zone).beginning_of_day
      @to_date = (to_date || @campaign.call_attempts.last.try(:created_at) || Time.now).in_time_zone(time_zone).end_of_day
    end
    
    
  end
end  