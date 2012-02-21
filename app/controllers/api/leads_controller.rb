module Api
  class LeadsController < ApiController  
    
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
      return true
    end
  
    def create
      return unless validate_params
      voter_list = VoterList.find_by_name_and_campaign_id("web_form_campaign_#{params[:campaign_id]}",params[:campaign_id])
      if voter_list.nil?
        voter_list =  VoterList.create(name: "web_form_campaign_#{params[:campaign_id]}", account_id: params[:account_id], active: true, campaign_id: params[:campaign_id], enabled: true)
      end    
      begin
        Voter.create!(:Phone => Voter.sanitize_phone(params[:phone_number]), :voter_list => voter_list, 
        :account_id => params[:account_id], :campaign_id => params[:campaign_id], CustomID: params[:custom_id],
        FirstName: params[:first_name], LastName: params[:last_name], MiddleName: params[:middle_name], Email: params[:email], address: params[:address],
         city: params[:city], state: params[:state], zip_code: params[:zip_code], country: params[:country], priority: "1")        
      rescue Exception => err
        render_json_response({status: 'error',code: '400', message: err.to_s})
        return
      end
      render_json_response({status: 'ok', code: '200', message: 'Lead Imported Successfully'})
    end
  
  end
end