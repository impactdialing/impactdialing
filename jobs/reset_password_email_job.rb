class ResetPasswordEmailJob
  @queue = :background_worker
  
  def self.perform(user_id)
    user = User.find(user_id)
    user_mailer = UserMailer.new
    user_mailer.reset_password(user)
  end
end