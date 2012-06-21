require Rails.root.join("jobs/heroku_resque_auto_scale")
class WelcomeEmailJob
  extend ::HerokuResqueAutoScale
  @queue = :worker_job
  
  
  def self.perform(user_id)
    user = User.find(user_id)
    user_mailer = UserMailer.new
    user_mailer.welcome_email(user)
    user_mailer.send_michael_welcome_email(user)
  end
end