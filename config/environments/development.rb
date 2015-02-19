ImpactDialing::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  #michael
  TWILIO_APP_SID   = "AP7d39738c833e144064374b12681bf0ba"
  TWILIO_ACCOUNT   = "AC422d17e57a30598f8120ee67feae29cd"
  TWILIO_AUTH      = "897298ab9f34357f651895a7011e1631"
  APP_NUMBER       = "7029797309"
  HOLD_MUSIC_URL   = "https://s3.amazonaws.com/hold_music/impactdialing_holdmusic_v1.mp3"
  MANDRILL_API_KEY = 'qlYdRXlyROwaN9Tqk1QrhA'

  #monitor
  MONITOR_TWILIO_APP_SID="APa5ea5d37745f53d3289b4326051743b0"

  PUSHER_APP_ID          = "6868"
  PUSHER_KEY             = "1e93714ff1e5907aa618"
  PUSHER_SECRET          = "26b438b5e27a3e84d59c"
  TWILIO_ERROR           = "http://status-impactdialing.heroku.com/twilio/error_development"
  STRIPE_PUBLISHABLE_KEY = "pk_test_C7afhsETXQncQqcBQ2Hr2f0M"
  STRIPE_SECRET_KEY      = "sk_test_EHZciy2zvJc6UelOAMdFX6wX"
  # http://rdoc.info/github/jnunemaker/httparty/HTTParty/ClassMethods#ssl_ca_file-instance_method
  Twilio.default_options[:ssl_ca_file] = ENV['SSL_CERT_FILE']
  
  config.after_initialize do
    Bullet.enable = true
    Bullet.alert = true
    Bullet.bullet_logger = true
    Bullet.console = true
    # Bullet.growl = true
    # Bullet.xmpp = { :account  => 'bullets_account@jabber.org',
    #                 :password => 'bullets_password_for_jabber',
    #                 :receiver => 'your_account@jabber.org',
    #                 :show_online_status => true }
    Bullet.rails_logger = true
    # Bullet.bugsnag = true
    # Bullet.airbrake = true
    Bullet.add_footer = true
    # Bullet.stacktrace_includes = [ 'your_gem', 'your_middleware' ]
  end
end
