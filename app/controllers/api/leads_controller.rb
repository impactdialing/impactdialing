module Api
  class LeadsController < ApiController
  
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
    
    end
  
  
    def create
      response_result = Hash.new
      validate_params(response_result)
      if response_result['error'].nil?
        voter_list = VoterList.find_by_name_and_campaign_id('web_form',params[:campaign_id])
        if voter_list.nil?
          voter_list =  VoterList.create(name: 'web_form', account_id: params[:account_id], active: true, campaign_id: params[:campaign_id], enabled: true)
        end
    
        begin
          Voter.create!(:Phone => params[:phone_number], :voter_list => voter_list, 
          :account_id => params[:account_id], :campaign_id => params[:campaign_id], CustomID: params[:custom_id],
          FirstName: params[:first_name], LastName: params[:last_name], MiddleName: params[:middle_name], Email: params[:email], address: params[:address],
           city: params[:city], state: params[:state], zip_code: params[:zip_code], country: params[:country], priority: "1")        
        rescue Exception => err
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