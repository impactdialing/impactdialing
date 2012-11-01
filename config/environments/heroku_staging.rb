ImpactDialing::Application.configure do

  #TWILIO_ACCOUNT="AC422d17e57a30598f8120ee67feae29cd"
  #TWILIO_AUTH="897298ab9f34357f651895a7011e1631"
  #TWILIO_APP_SID="AP9a7f90ed206c430587a5c534c02a558f"
  #APP_NUMBER="6502626881"
  
  TWILIO_ACCOUNT="AC8214b5932e8b89f2c8c630d582f1f42c"
  TWILIO_AUTH="638089b9f24ef21eb1710e12bc508fa9"
  TWILIO_APP_SID="AP70733f2b5c43898e634abe07e4d69f6b"
  APP_NUMBER="3212802381"

  PORT = 80
  PUSHER_APP_ID="6964"
  PUSHER_KEY="6f37f3288a3762e60f94"
  PUSHER_SECRET="b9a1cfc2c1ab4b64ad03"
  MONITOR_TWILIO_APP_SID="AP06c5b96cedaf433b9fe0e6d865aab104"
  TWILIO_ERROR = "http://status-impactdialing.heroku.com/twilio/error_staging"
  HOLD_MUSIC_URL = "https://s3.amazonaws.com/hold_music/impactdialing_holdmusic_v1.mp3"

  # Settings specified here will take precedence over those in config/environment.rb

  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # See everything in the log (default is :info)
  # config.log_level = :debug

  config.active_support.deprecation = :log

  # Use a different logger for distributed setups
  # config.logger = SyslogLogger.new
  if ["heroku_staging"].include?(Rails.env)
    config.logger = Logger.new(STDOUT)
  end

  # Use a different cache store in production
  config.cache_store = :dalli_store, 'mc5.ec2.northscale.net', { :username => "app2269278%40heroku.com", :password => "fvuV1zolpkAe345T" }

  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!
end
