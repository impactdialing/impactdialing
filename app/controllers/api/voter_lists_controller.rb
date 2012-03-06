module Api
  class VoterListsController < ApiController
    
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
      
      account = Account.find(params[:account_id])
      emails = account.users.collect{|user| user.email}
      unless emails.include?(params[:email])
        render_json_response({status: 'error', code: '401' , message: 'Unauthorized: Cannot access this account'})
        return false
      end      
      
      upload = params[:upload]["datafile"]
      unless VoterList.valid_file?(upload.original_filename)
        render_json_response({status: 'error', code: '400' , message: 'Wrong file format. Please upload a comma-separated value (CSV) or tab-delimited text (TXT) file. If your list is in Excel format (XLS or XLSX), use \"Save As\" to change it to one of these formats.'})
        return false
      end      
      
      return true
    end
    
    
    def create
      return unless validate_params
      
    end
    
  end
end  
