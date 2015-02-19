if ["heroku", "heroku_staging"].include?(Rails.env)
  Rails.application.config.logger       = Logger.new(STDOUT)
  Rails.application.config.logger.level = Logger.const_get(ENV['LOG_LEVEL'] ?  ENV['LOG_LEVEL'].upcase : 'INFO')
end