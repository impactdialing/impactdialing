ImpactDialing::Application.configure do
  TWILIO_ACCOUNT="AC422d17e57a30598f8120ee67feae29cd"
  TWILIO_AUTH="897298ab9f34357f651895a7011e1631"
  TWILIO_APP_SID="AP338eb7933a05fa18fe65ee269beb7820"
  APP_NUMBER="4157020991"
  HOST = APP_HOST = "staging.impactdialing.com"
  PORT = 80
  TEST_CALLER_NUMBER="8583679749"
  TEST_VOTER_NUMBER="4154486970"
  PUSHER_APP_ID="7054"
  PUSHER_KEY="e6c025759382ac4172ad"
  PUSHER_SECRET="feb564060d2c27aa9d2b"

  MONITOR_TWILIO_APP_SID="AP00cfdf8773e2425bb4748ada7478c0fd"
  REDIS="redis://redistogo:d71d12bad7803b45796a690bb9fe89d3@guppy.redistogo.com:9307/"

  # Settings specified here will take precedence over those in config/environment.rb

  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local = false
  config.action_controller.perform_caching             = true

  # See everything in the log (default is :info)
  config.log_level = :debug

  config.active_support.deprecation = :log

  # Use a different logger for distributed setups
  # config.logger = SyslogLogger.new

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!
end
