require 'heroku'

module HerokuResqueAutoScale
  module Scaler
    class << self
      @@heroku = Heroku::Client.new(ENV['HEROKU_USER'], ENV['HEROKU_PASS'])

      def worker_count(queue_name)
        Resque.workers.count { |worker| worker.queues.include?(queue_name) }
      end
      
      def working_job_count(queue_name)
        Resque.working.count { |worker| worker.job["queue"] == queue_name }
      end
      
     def workers(queue_name, qty)
        @@heroku.ps_scale(ENV['HEROKU_APP'], :type=>queue_name, :qty=>qty)
     end

      def pending_job_count(queue_name)
        Resque.size(queue_name)
      end
      
      def restart_web_dyno(dyno)
        @heroku.restart(ENV['HEROKU_APP'], dyno)
      end
      
    end
  end

  def after_perform_scale_down(*args)
    Scaler.workers(1) if Scaler.working_job_count == 1
  end

  def after_enqueue_scale_up(*args)
    workers_to_scale = Scaler.working_job_count + Scaler.pending_job_count - Scaler.worker_count
    if workers_to_scale > 0
      Scaler.workers(Scaler.working_job_count + Scaler.pending_job_count + 1)
    end
  end
  
 
end