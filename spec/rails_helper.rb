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

require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'webmock/rspec'

require 'impact_platform'

require 'paperclip/matchers'


Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

ActiveRecord::Migration.check_pending! if defined?(ActiveRecord::Migration)

VCR.configure do |c|
  c.debug_logger                            = File.open(Rails.root.join('log', 'vcr-debug.log'), 'w')
  c.cassette_library_dir                    = Rails.root.join 'spec/fixtures/vcr_cassettes'
  c.ignore_localhost                        = true
  c.allow_http_connections_when_no_cassette = true
  c.hook_into :webmock
end

RSpec.configure do |config|

  def webmock_disable_net!
    WebMock.disable_net_connect!({
      allow_localhost: true,
      allow: [/saucelabs.com/]
    })
  end

  config.fixture_path = Rails.root.join('spec', 'fixtures')

  config.infer_spec_type_from_file_location!

  config.profile_examples = 10
  config.include FactoryGirl::Syntax::Methods
  config.include TwilioRequestStubs
  config.include FactoryGirlImportHelpers
  config.include Paperclip::Shoulda::Matchers
  config.include WebLoginHelpers
  config.include ResqueHelpers
  config.include DialQueueHelpers
  config.include AssertionHelpers

  config.mock_with :rspec
  config.use_transactional_fixtures = false

  config.before(:suite) do
    CapybaraConfig.switch_to_webkit
    WebMock.allow_net_connect!
    DatabaseCleaner.clean_with :truncation
  end

  config.before(:example) do |example|
    DatabaseCleaner.strategy = :truncation

    if example.metadata[:js]
      if example.metadata[:file_uploads]
        CapybaraConfig.switch_to_selenium
      else
        CapybaraConfig.switch_to_webkit
      end
    end

    if example.metadata[:js] or example.metadata[:type] == :feature
      VCR.configure do |c|
        c.allow_http_connections_when_no_cassette = true
      end
    end
  end

  config.before(:example, type: :feature) do |example|
    if Capybara.current_driver != :rack_test
      DatabaseCleaner.strategy = :truncation
    end
  end

  config.before(:example) do
    DatabaseCleaner.start 
  end

  config.after(:example) do |example|
    if example.metadata[:js] or example.metadata[:type] == :feature
      VCR.configure do |c|
        c.cassette_library_dir = Rails.root.join 'spec/fixtures/vcr_cassettes'
        c.hook_into :webmock
      end
    end
    # sleep(5) # this helps tests pass on sauce
    Redis.new.flushall
    DatabaseCleaner.clean
  end
end

require 'capybara/rails'
require_relative 'capybara_config'
require 'sauce_helper' if ENV['USE_SAUCE']
