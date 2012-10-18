class HerokuQueuingTimeLogger
  
  def initialize(app, options={})
    @app = app
    @options = options
  end

  def call(env)
    status, headers, response = @app.call(env)
    
    limit = @options[:limit] || 1000
    
    if queue_wait(env) > limit
       Rails.logger.error "HTTP_X_HEROKU_QUEUE_WAIT_TIME #{queue_wait(env)}ms for #{uri(env)}"
    end

    [status, headers, response]
  end
  
  
  private
  
  def queue_wait(env)
    env["HTTP_X_HEROKU_QUEUE_WAIT_TIME"].to_i
  end
  
  def uri(env)
    env["REQUEST_URI"].to_s
  end
end