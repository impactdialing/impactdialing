require 'heroku'

module HerokuResqueAnsweredAutoScale
  
  module Scaler
    class << self
      @@heroku = Heroku::Client.new(ENV['HEROKU_USER'], ENV['HEROKU_PASS'])
      
      def workers(qty)
        @@heroku.ps_scale(ENV['HEROKU_APP'], :type=>'answered_worker', :qty=>qty)
      end

    end
  end

  def after_perform_scale_down(*args)
    Scaler.workers(0)
  end

  def after_enqueue_scale_up(*args)
    Scaler.workers(1)
  end
end