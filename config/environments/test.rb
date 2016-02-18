if ENV['TEST_ENV_NUMBER'].present?
  if ENV['DATABASE_URL'].present?
    new_url = "#{ENV['DATABASE_URL']}#{ENV['TEST_ENV_NUMBER']}"

    p "Using: #{new_url}"

    ENV['DATABASE_URL']                 = new_url
    ENV['DATABASE_READ_SLAVE1_URL']     = new_url
    ENV['DATABASE_READ_SLAVE2_URL']     = new_url
    ENV['DATABASE_SIMULATOR_SLAVE_URL'] = new_url
  end

  if ENV['REDIS_URL'].present?
    new_url = "#{ENV['REDIS_URL']}/#{ENV['TEST_ENV_NUMBER'] || 0}"

    p "Using: #{new_url}"

    ENV['REDIS_URL'] = new_url
  end
  if ENV['SIMPLECOV'].present?
    p "WARNING: Skipping coverage report. Run test suite sequentially for coverage."
  end
else
  # some things don't work in parallel
  if ENV['SIMPLECOV'].present?
    require 'simplecov'
    SimpleCov.start 'rails'
    SimpleCov.coverage_dir("coverage")
  end
end

require 'shoulda'
require 'factory_girl'

ImpactDialing::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  if ENV['TEST_ENV_NUMBER'].present?
    parallel_dir = Rails.root.join('tmp', 'cache', "paralleltests_#{ENV['TEST_ENV_NUMBER']}")
    config.cache_store = :file_store, File.join(parallel_dir, 'pages')
    config.assets.cache = Sprockets::Cache::FileStore.new(File.join(parallel_dir, 'assets'))
  end
  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = true
  config.allow_concurrency = false

  # Configure static asset server for tests with Cache-Control for performance.
  config.serve_static_assets  = true
  config.static_cache_control = "public, max-age=3600"

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  HOLD_MUSIC_URL = "hold_music"

  HOST = 'localhost'
  PORT = 3000

  ENV['PAGER_DUTY_SERVICE'] ||= '5ee2a001bc0b41e48bb587a66d63f4a6'

  redis = Redis.new
  redis.config(:set, 'hash-max-ziplist-entries', 1024)
  redis.config(:set, 'hash-max-ziplist-value', 1024)
end
