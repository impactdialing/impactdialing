module Api
  class AccountsController < ApiController
    
    def validate_params
      validate_email_not_blank(params[:email])
    end
    
    
    def id
      return unless validate_params   
      user = User.authenticate(params[:email], params[:password])
      if user.blank?
        render_json_response({status: 'error', code: '400' , message: 'The email or password you entered was incorrect.'})
      else
        account = user.account
        data = {id: account.id}
        render_json_response({status: 'ok', code: '200' , message: "Success", data: data})        
      end      
    end
    
  end
end  