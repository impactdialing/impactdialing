# Load the rails application
require File.expand_path('../application', __FILE__)


# Initialize the rails application
ImpactDialing::Application.initialize!
if Rails.env == 'heroku'
  DIALER_LOGGER = Rails.logger
else
  DIALER_LOGGER = Logger.new(STDOUT)
end
require "csv"
