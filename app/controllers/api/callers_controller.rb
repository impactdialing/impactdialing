module Api
  class CallersController < ApiController
    def validate_params(response)
      begin
        Campaign.find(params[:campaign_id])
        Account.find(params[:account_id])
      rescue Exception => err
        response['error'] = {code: '404', message:err.to_s}          
        return
      end
      
      if !params[:campaign_id].blank? && !params[:account_id].blank?
        campaign = Campaign.find(params[:campaign_id])
        if campaign.account_id.to_s != params[:account_id]
          response['error'] = {code: '400' , message: 'Campaign is not assigned to the account'}
          return
        end
      end    
      
      if params[:email].blank?
        response['error'] = {code: '400', message: 'Email cannot be blank'}
        return
      end
    
    end
    
    def create
      response_result = Hash.new
      validate_params(response_result)     
      if response_result['error'].nil?
        begin
          Caller.create!(email: params[:email], account_id: params[:account_id], password: params[:password], campaign_id: params[:campaign_id])
        rescue Exception => err
          puts err
          response_result['error'] = {code: '400', message: err.to_s}
        end
        if response_result['error'].blank?
          response_result['success'] = {code: '200', message:'Lead Imported Successfully'}     
        end
      end
      render json: response_result      
    end
  end
end