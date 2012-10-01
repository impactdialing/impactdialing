require Rails.root.join("jobs/heroku_resque_auto_scale")
class ResetPasswordEmailJob
  extend ::HerokuResqueAutoScale
  @queue = :background_worker_job


  def self.perform(user_id)
    user = User.find(user_id)
    user_mailer = UserMailer.new
    user_mailer.reset_password(user)
  end
  def after_perform_scale_down(*args)
    Scaler.workers(@queue.to_s,1) if Scaler.working_job_count(@queue.to_s) == 1
  end

  def after_enqueue_scale_up(*args)
     workers_to_scale = Scaler.working_job_count(@queue.to_s) + Scaler.pending_job_count(@queue.to_s) - Scaler.worker_count(@queue.to_s)
     if workers_to_scale > 0
       Scaler.workers(@queue.to_s, Scaler.working_job_count(@queue.to_s) + Scaler.pending_job_count(@queue.to_s) + 1)
     end
   end


end