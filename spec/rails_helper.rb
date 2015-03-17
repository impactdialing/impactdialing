# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RACK_QUEUE_METRICS_INTERVAL'] = "#{(3600 * 24)}"
ENV["RAILS_ENV"] ||= 'test'
if ENV['RAILS_ENV'] == 'development'
  ENV['RAILS_ENV'] = 'test'
end
ENV['REDIS_URL'] ||= 'redis://localhost:6379'
ENV['TWILIO_CALLBACK_HOST'] ||= 'test.com'
ENV['CALL_END_CALLBACK_HOST'] ||= 'test.com'
ENV['INCOMING_CALLBACK_HOST'] ||= 'test.com'
ENV['VOIP_API_URL'] ||= 'test.com'
ENV['TWILIO_CALLBACK_PORT'] ||= '80'
ENV['RECORDING_ENV'] = 'test'
ENV['CALLIN_PHONE'] ||= '5555551234'

require 'spec_helper'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'webmock/rspec'
require 'impact_platform'
require 'paperclip/matchers'

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  
  config.profile_examples = 10
  config.include FactoryGirl::Syntax::Methods
  config.include TwilioRequestStubs
  config.include FactoryGirlImportHelpers
  config.include Paperclip::Shoulda::Matchers

  config.mock_with :rspec

  config.before(:suite) do
    WebMock.allow_net_connect!

    if ENV['RAILS_ENV'] == 'e2e'
      DatabaseCleaner.strategy = :truncation
    else
      DatabaseCleaner.strategy = :transaction
    end
    DatabaseCleaner.clean_with :truncation

    module ImpactPlatform::Heroku::UploadDownloadHooks
      alias_method :real_after_enqueue_scale_up, :after_enqueue_scale_up

      def after_enqueue_scale_up(*args); end
    end
  end

  config.after(:suite) do
    DatabaseCleaner.clean

    module ImpactPlatform::Heroku::UploadDownloadHooks
      alias_method :after_enqueue_scale_up, :real_after_enqueue_scale_up
    end
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  if ENV['RAILS_ENV'] == 'e2e'
    config.use_transactional_fixtures = false
  else
    config.use_transactional_fixtures = true
  end

  config.infer_spec_type_from_file_location!
end
