require Rails.root.join("jobs/heroku_resque_auto_scale")
class DeliverInvitationEmailJob
  extend ::HerokuResqueAutoScale
  @queue = :background_worker_job


  def self.perform(new_user_id, current_user_id)
    new_user = User.find(new_user_id)
    current_user = User.find(current_user_id)
    user_mailer = UserMailer.new
    user_mailer.deliver_invitation(new_user, current_user)
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