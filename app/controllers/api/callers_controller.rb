module Api
  class CallersController < ApiController

    def validate_params
      validate_campaign(params[:campaign_id]) && validate_account(params[:account_id]) && validate_campaign_belongs_to_account(params[:campaign_id], params[:account_id]) && validate_email_not_blank(params[:email])
    end
    
    def create
      return unless validate_params
      begin
        Caller.create!(email: params[:email], account_id: params[:account_id], password: params[:password], campaign_id: params[:campaign_id])
      rescue Exception => err
        render_json_response({status: 'error', code: '400', message: err.to_s})
        return
      end
      render_json_response({status: 'ok', code: '200', message: 'Caller created successfully'})
    end
      
  end
end