# Load the rails application
require File.expand_path('../application', __FILE__)
require Rails.root.join("lib/redis_connection")

# Initialize the rails application
ImpactDialing::Application.initialize!
APP_URL="http://#{APP_HOST}"
if Rails.env == 'heroku'
  DIALER_LOGGER = Rails.logger
else
  DIALER_LOGGER = Logger.new(Rails.root.join("log", "predictive_dialer_#{Rails.env}.log"))
end
HOLD_VERSION = File::mtime(Rails.root.join("public", "wav","hold.mp3"))
require "csv"