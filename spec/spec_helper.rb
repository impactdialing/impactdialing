require 'rubygems'
require 'spork'
require 'spork/ext/ruby-debug'
require 'simplecov'


SimpleCov.start 'rails' do
  add_filter 'environment.rb'
end

Spork.prefork do
  # This file is copied to spec/ when you run 'rails generate rspec:install'
  ENV["RAILS_ENV"] ||= 'test'

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

    config.before(:suite) do
       DatabaseCleaner.strategy = :transaction
    end

    config.after(:suite) do
      DatabaseCleaner.clean_with(:truncation)
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
    config.use_transactional_fixtures = true
    config.fixture_path = Rails.root.join('spec/fixtures')
    #
    # == Notes
    #
    # For more information take a look at Spec::Runner::Configuration and Spec::Runner
  end

  require "factories"
  include ActionDispatch::TestProcess

  def login_as(user)
    @controller.stub(:current_user).and_return(user)
    session[:user] = user.id
    session[:caller] = user.id
  end

  def create_user_and_login
    user = Factory.build :user
    visit '/client/login'
    fill_in 'Email address', :with => user.email
    fill_in 'Pick a password', :with => user.new_password
    click_button 'Sign up'
    click_button 'I and the company or organization I represent accept these terms.'
  end

  def fixture_path
    Rails.root.join('spec/fixtures/').to_s
  end

  def fixture_file_upload(path, mime_type = nil, binary = false)
    Rack::Test::UploadedFile.new("#{fixture_path}#{path}", mime_type, binary)
  end

end

Spork.each_run do

end
