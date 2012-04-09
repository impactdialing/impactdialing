require 'heroku'

module HerokuResqueAutoScale
  module Scaler
    class << self
      @@heroku = Heroku::Client.new(ENV['HEROKU_USER'], ENV['HEROKU_PASS'])

      def workers
        @@heroku.info(ENV['HEROKU_APP'])[:workers].to_i
      end

      def workers=(qty)
        @@heroku.set_workers(ENV['HEROKU_APP'], qty)
        # If you're running on the Cedar stack, do this instead.
        # @@heroku.ps_scale(ENV['HEROKU_APP'], :type=>'worker', :qty=>qty)
      end

      def job_count
        Resque.info[:pending].to_i
      end
    end
  end

  def after_perform_scale_down(*args)
    # Nothing fancy, just shut everything down if we have no jobs
    Scaler.workers = 0 if Scaler.job_count.zero?
  end
