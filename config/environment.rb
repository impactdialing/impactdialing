# Load the rails application
require File.expand_path('../application', __FILE__)

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

require 'chargify_api_ares'

chargify_config = YAML::load_file(Rails.root.join("config","chargify.yml"))

Chargify.configure do |c|
  c.subdomain = chargify_config['subdomain']
  c.api_key   = chargify_config['api_key']
end