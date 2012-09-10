ImpactDialing::Application.configure do
  TWILIO_ACCOUNT="AC422d17e57a30598f8120ee67feae29cd"
  TWILIO_AUTH="897298ab9f34357f651895a7011e1631"
  TWILIO_APP_SID="AP9154d646a7c8499caecc6b37ee5980f5"
  APP_NUMBER="4157020991"
  HOST = APP_HOST = "preprod.impactdialing.com"
  PORT = 80
  TEST_CALLER_NUMBER="8583679749"
  TEST_VOTER_NUMBER="4154486970"
  PUSHER_APP_ID="11524"
  PUSHER_KEY="c60c0d7be971c97db062"
  PUSHER_SECRET="417aa7002a16b9b6053a"

  MONITOR_TWILIO_APP_SID="AP57b0a3ca229f42049580004fb65b084e"

  # Settings specified here will take precedence over those in config/environment.rb

  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local = false
  config.action_controller.perform_caching             = true

  # See everything in the log (default is :info)
  config.log_level = :error

  config.active_support.deprecation = :log
end
