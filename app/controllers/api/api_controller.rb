class ApiController < ApplicationController
    before_filter :authenticate_account
    
    def authenticate_account
      if params[:api_key] != '1mp@ctd1@l1ng'
        render json: {error: {code: "401", message: "UnauthorizedAccess"}}        
        return
      end
    end
end