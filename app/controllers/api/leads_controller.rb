module Api
  class LeadsController < ApiController  
    
    def validate_params
      validate_campaign(params[:campaign_id]) && validate_account(params[:account_id]) && validate_campaign_belongs_to_account(params[:campaign_id], params[:account_id])      
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