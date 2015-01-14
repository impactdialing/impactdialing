require 'simplecov'
SimpleCov.start 'rails'
SimpleCov.coverage_dir("#{Rails.env}/coverage")

HOST = 'localhost'
PORT = 3000

MANDRILL_API_KEY='qlYdRXlyROwaN9Tqk1QrhA'

ImpactDialing::Application.configure do
  ENV['PAGER_DUTY_SERVICE'] ||= '5ee2a001bc0b41e48bb587a66d63f4a6'

  config.cache_classes                              = true
  config.whiny_nils                                 = true
  config.consider_all_requests_local                = true
  config.action_controller.perform_caching          = false
  config.action_controller.allow_forgery_protection = false
  config.action_mailer.delivery_method              = :test
  config.active_support.deprecation                 = :log

  require 'shoulda'
  require 'factory_girl'

  APP_NUMBER="SomeNumber"
  PUSHER_APP_ID="blah"
  PUSHER_KEY="blahblah"
  PUSHER_SECRET="blahblahblah"
  TWILIO_ACCOUNT="blahblahblah"
  TWILIO_AUTH="blahblahblah"
  TWILIO_APP_SID="blahdahhahah"
  TWILIO_ERROR = "blah"
  HOLD_MUSIC_URL = "hold_music"
  MONITOR_TWILIO_APP_SID="blah"
  STRIPE_PUBLISHABLE_KEY = "pk_test_C7afhsETXQncQqcBQ2Hr2f0M"
  STRIPE_SECRET_KEY = "sk_test_EHZciy2zvJc6UelOAMdFX6wX"
end
