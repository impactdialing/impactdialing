module Api
  class ApiController < ApplicationController
    before_filter :authenticate_account

    def authenticate_account
      if params[:api_key] != '1mp@ctd1@l1ng'
        render_json_response({status: 'error', code: "401", message: "UnauthorizedAccess"})
        return
      end
    end
    
    def validate_campaign(campaign_id)
      begin
        Campaign.find(campaign_id)      
      rescue Exception => err
        render_json_response({status: 'error', code: '404', message: err.to_s})
        return false
      end      
      return true
    end
    
    def validate_account(account_id)
      begin
        Account.find(account_id)
      rescue Exception => err
        render_json_response({status: 'error', code: '404', message: err.to_s})
        return false
      end      
      return true
    end
    
    def validate_campaign_belongs_to_account(campaign_id, account_id)
      if !campaign_id.blank? && !account_id.blank?
        campaign = Campaign.find(campaign_id)
        if campaign.account_id.to_s != account_id
          render_json_response({status: 'error', code: '400' , message: 'Campaign is not assigned to the account'})
          return false
        end
      end        
      return true  
    end
    
    def validate_email_not_blank(email)
      if email.blank?
        render_json_response({status: 'error', code: '400', message: 'Email cannot be blank'})
        return false
      end
      return true      
    end
    
    def validate_email_belongs_to_account(account_id, email)
      account = Account.find(account_id)
      emails = account.users.collect{|user| user.email}
      unless emails.include?(email)
        render_json_response({status: 'error', code: '401' , message: 'Unauthorized: Cannot access this account'})
        return false
      end      
      return true      
    end
    

    def render_json_response(response)
      json_structure = {
          :status => response[:status],
          :message => response[:message],
      }
      render_options = {:json => json_structure}  
      unless response[:data].nil?
        render_options[:json][:data] = response[:data]
      else

      end      
      render_options[:status] = response[:code]      
      render(render_options)
    end
  end
end
