module Api
  class CallersController < ApiController

    def validate_params
      begin
        Campaign.find(params[:campaign_id])
        Account.find(params[:account_id])
      rescue Exception => err
        render_json_response({status: 'error', code: '404', message:err.to_s})          
        return false
      end
      
      if !params[:campaign_id].blank? && !params[:account_id].blank?
        campaign = Campaign.find(params[:campaign_id])
        if campaign.account_id.to_s != params[:account_id]
          render_json_response({status: 'error', code: '400' , message: 'Campaign is not assigned to the account'})
          return false
        end
      end    
      
      if params[:email].blank?
        render_json_response({status: 'error', code: '400', message: 'Email cannot be blank'})
        return false
      end
      return true
    
    end
    
    def create
      return unless validate_params
      begin
        Caller.create!(email: params[:email], account_id: params[:account_id], password: params[:password], campaign_id: params[:campaign_id])
      rescue Exception => err
        render_json_response({status: 'error', code: '400', message: err.to_s})
        return
      end
      render_json_response({status: 'ok', code: '200', message:'Caller created successfully'})
    end
      
  end
end