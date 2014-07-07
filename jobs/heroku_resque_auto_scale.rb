# require 'heroku'

module HerokuResqueAutoScale
  module Scaler
    class << self
      # @@heroku = Heroku::Client.new(ENV['HEROKU_USER'], ENV['HEROKU_PASS'])

      def worker_count(queue_name)
        0
        # Resque.workers.count { |worker| worker.queues.include?(queue_name) }
      end

      def working_job_count(queue_name)
        0
        # Resque.working.count { |worker| worker.job["queue"] == queue_name }
      end

     def workers(queue_name, qty)
      1
        # @@heroku.ps_scale(ENV['HEROKU_APP'], :type=>queue_name, :qty=>qty)
     end

      def pending_job_count(queue_name)
        0
        # Resque.size(queue_name)
      end

      def restart_web_dyno(dyno)
        true
        # @heroku.restart(ENV['HEROKU_APP'], dyno)
      end

    end
  end


end