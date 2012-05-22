require 'heroku'

module HerokuResqueAutoScale
  module Scaler
    class << self
      @@heroku = Heroku::Client.new(ENV['HEROKU_USER'], ENV['HEROKU_PASS'])

      def worker_count
        Resque.info[:workers].to_i
      end

      def workers(qty)
        @@heroku.ps_scale(ENV['HEROKU_APP'], :type=>'worker_job', :qty=>qty)
      end

      def pending_job_count
        Resque.info[:pending].to_i
      end
      
      def working_job_count
        Resque.info[:working].to_i
      end
      
    end
  end

  def after_perform_scale_down(*args)
    sleep(10)
    Scaler.workers(0) if Scaler.working_job_count.zero?
  end

  def after_enqueue_scale_up(*args)
    workers_to_scale = Scaler.working_job_count + Scaler.pending_job_count - Scaler.worker_count
    if workers_to_scale > 0
      Scaler.workers(Scaler.working_job_count + Scaler.pending_job_count)
    end
  end
end