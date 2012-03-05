module Api
  module Accounts
  class CampaignsController < ApiController
    
    def validate_params
      begin
        Account.find(params[:account_id])
      rescue Exception => err
        render_json_response({status: 'error', code: '404', message: err.to_s})
        return false
      end
      
      if params[:email].blank?
        render_json_response({status: 'error', code: '400', message: 'Email cannot be blank'})
        return false
      end      
      
      account = Account.find(params[:account_id])
      emails = account.users.collect{|user| user.email}
      unless emails.include?(params[:email])
        render_json_response({status: 'error', code: '401' , message: 'Unauthorized: Cannot access this account'})
        return false
      end      
      return true
    
    end
    
    
    def index
      return unless validate_params
      account = Account.find(params[:account_id])
      campaigns = account.campaigns
      data = campaigns.collect {|campaign| {id: campaign.id, name: campaign.name}}
      render_json_response({status: 'ok', code: '200', message: "Success", data: data})      
    end

  end
 end
  
end  