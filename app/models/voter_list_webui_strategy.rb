class VoterListWebuiStrategy
  
  def initialize
    @user_mailer = UserMailer.new
  end
  
  def response(response, params)
    @user_mailer.voter_list_upload(response, params[:domain], params[:email],params[:voter_list_name])
  end
end