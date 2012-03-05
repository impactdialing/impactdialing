module Api
  class ApiController < ApplicationController
    before_filter :authenticate_account

    def authenticate_account
      if params[:api_key] != '1mp@ctd1@l1ng'
        render_json_response({status: 'error', code: "401", message: "UnauthorizedAccess"})
        return
      end
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
