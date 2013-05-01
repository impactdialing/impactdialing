require 'rubygems'
require 'spork'
require 'spork/ext/ruby-debug'
require 'simplecov'
require 'capybara/rspec'




SimpleCov.start 'rails' do
  add_filter 'environment.rb'
end

Spork.prefork do
  # This file is copied to spec/ when you run 'rails generate rspec:install'
  ENV["RAILS_ENV"] = 'integration_test'

  require File.expand_path("../../config/environment", __FILE__)
  require 'rspec/rails'
  require 'spork/ext/ruby-debug'


  # Requires supporting ruby files with custom matchers and macros, etc,
  # in spec/support/ and its subdirectories.
  Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}
  Dir[Rails.root.join("spec/shared/**/*.rb")].each {|f| require f}
  #Dir[Rails.root.join("simulator/new_simulator.rb")].each {|f| require f}

  RSpec.configure do |config|
    config.before(:each) do
      $redis_call_flow_connection.flushALL
    end
    # == Mock Framework
    #
    # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
    #
    # config.mock_with :mocha
    # config.mock_with :flexmock
    # config.mock_with :rr
    config.mock_with :rspec

  #   class ActiveRecord::Base
  #     mattr_accessor :shared_connection
  #     @@shared_connection = nil

  #     def self.connection
  #       @@shared_connection || ConnectionPool::Wrapper.new(:size => 1) { retrieve_connection }
  #   end
  # end
  # ActiveRecord::Base.shared_connection = ActiveRecord::Base.connection



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


# Capybara.register_driver :poltergeist do |app|
#   Capybara::Poltergeist::Driver.new(app, { js_errors: true })
# end

Capybara.javascript_driver = :selenium
Capybara.current_driver = :selenium
# Capybara.app_host = 'http://impact.localtunnel.net'
# Capybara.server_port = '8989'


Spork.each_run do

end
