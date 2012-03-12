module Api
  class CampaignsController < ApiController
    
    def validate_params
      validate_account(params[:account_id]) && validate_email_not_blank(params[:email]) && validate_email_belongs_to_account(params[:account_id], params[:email])      
    end
    
    
    def index
      return unless validate_params
      account = Account.find(params[:account_id])
      campaigns = account.campaigns.active
      data = campaigns.collect {|campaign| {id: campaign.id, name: campaign.name}}
      render_json_response({status: 'ok', code: '200', message: "Success", data: data})      
    end

  end
  
end  