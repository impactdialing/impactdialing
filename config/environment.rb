# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
ImpactDialing::Application.initialize!
APP_URL="http://#{APP_HOST}"
DIALER_LOGGER = Logger.new(Rails.root.join("log", "predictive_dialer_#{Rails.env}.log"))
