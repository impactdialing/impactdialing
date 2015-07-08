# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RACK_QUEUE_METRICS_INTERVAL'] = "#{(3600 * 24)}"
ENV["RAILS_ENV"] ||= 'test'
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
require 'capybara/rails'

require 'impact_platform'

require 'paperclip/matchers'

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.check_pending! if defined?(ActiveRecord::Migration)

VCR.configure do |c|
  c.debug_logger                            = File.open(Rails.root.join('log', 'vcr-debug.log'), 'w')
  c.cassette_library_dir                    = Rails.root.join 'spec/fixtures/vcr_cassettes'
  c.ignore_localhost                        = true
  c.allow_http_connections_when_no_cassette = true
  c.hook_into :webmock
end

RSpec.configure do |config|
  def capybara_switch_to_webkit
    Capybara.javascript_driver = :webkit
    if Capybara.page.driver.respond_to? :allow_url
      Capybara.page.driver.allow_url("js.stripe.com")
      Capybara.page.driver.allow_url("static.twilio.com")
      Capybara.page.driver.allow_url("api.stripe.com")
      Capybara.page.driver.allow_url("api.usersnap.com")
      Capybara.page.driver.allow_url("d3mvnvhjmkxpjz.cloudfront.net")
      Capybara.page.driver.allow_url("d3dy5gmtp8yhk7.cloudfront.net")
      Capybara.page.driver.allow_url("beacon.errorception.com")
      Capybara.page.driver.allow_url("stats.pusher.com")
    end
  end
  capybara_switch_to_webkit

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  config.profile_examples = 10
  config.include FactoryGirl::Syntax::Methods
  config.include TwilioRequestStubs
  config.include FactoryGirlImportHelpers
  config.include Paperclip::Shoulda::Matchers
  config.include WebLoginHelpers
  config.include ResqueHelpers
  config.include DialQueueHelpers

  config.mock_with :rspec
  config.use_transactional_fixtures = false

  config.before(:suite) do
    WebMock.allow_net_connect!
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with :truncation
  end

  config.after(:suite) do
    DatabaseCleaner.clean
  end

  config.before(:example) do |example|
    if example.metadata[:js]
      if example.metadata[:file_uploads]
        Capybara.javascript_driver = :selenium
      else
        capybara_switch_to_webkit
      end
    end

    if example.metadata[:js] or example.metadata[:type] == :feature
      VCR.configure do |c|
        c.allow_http_connections_when_no_cassette = true
      end
    end
    DatabaseCleaner.start
  end

  config.after(:example) do |example|
    if example.metadata[:js] or example.metadata[:type] == :feature
      VCR.configure do |c|
        c.cassette_library_dir = Rails.root.join 'spec/fixtures/vcr_cassettes'
        c.hook_into :webmock
      end
    end
    Redis.new.flushall
    DatabaseCleaner.clean
  end
end
