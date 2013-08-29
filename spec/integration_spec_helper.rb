require 'rubygems'
require 'spork'
require 'spork/ext/ruby-debug'
require 'simplecov'
require 'capybara/rspec'





SimpleCov.start 'rails' do
  add_filter 'environment.rb'
end

Spork.prefork do
  ENV["RAILS_ENV"] = 'integration_test'
  require "pusher-fake"

  require File.expand_path("../../config/environment", __FILE__)
  require 'rspec/rails'
  require 'spork/ext/ruby-debug'

  Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}
  Dir[Rails.root.join("spec/shared/**/*.rb")].each {|f| require f}

  RSpec.configure do |config|

    config.before(:each) do
      $redis_call_flow_connection.flushALL
    end

    config.mock_with :rspec

    config.before(:suite) do
       DatabaseCleaner.strategy = :truncation
    end

    config.after(:suite) do
      DatabaseCleaner.clean_with(:truncation)
    end

    config.before(:each) do
      DatabaseCleaner.start
    end

    config.before(:all) do
      DatabaseCleaner.start
    end


    config.after(:each) do
        DatabaseCleaner.clean
        PusherFake::Channel.reset
    end

    config.after(:all) do
        DatabaseCleaner.clean
    end

    # If you're not using ActiveRecord, or you'd prefer not to run each of your
    # examples within a transaction, remove the following line or assign false
    # instead of true.
    config.use_transactional_fixtures = false
    ActiveRecord::ConnectionAdapters::ConnectionPool.class_eval do
      def current_connection_id
        Thread.main.object_id
      end
    end


    # Make it so poltergeist (out of thread) tests can work with transactional fixtures
    # REF http://opinionated-programmer.com/2011/02/capybara-and-selenium-with-rspec-and-rails-3/#comment-220


    config.fixture_path = Rails.root.join('spec/fixtures')
    #
    # == Notes
    #
    # For more information take a look at Spec::Runner::Configuration and Spec::Runner
     config.include Features::DialinHelpers, type: :feature
  end

  require "factories"
  include ActionDispatch::TestProcess


  class ActionDispatch::IntegrationTest
    include Capybara::DSL
  end

  def login_as(user)
    @controller.stub(:current_user).and_return(user)
    session[:user] = user.id
    session[:caller] = user.id
  end

  def fixture_path
    Rails.root.join('spec/fixtures/').to_s
  end

  def fixture_file_upload(path, mime_type = nil, binary = false)
    Rack::Test::UploadedFile.new("#{fixture_path}#{path}", mime_type, binary)
  end

end

Capybara.javascript_driver = :selenium
Capybara.app_host = 'http://127.0.0.1:8989'
Capybara.server_port = '8989'

Spork.each_run do

end
