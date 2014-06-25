require 'rubygems'
require 'spork'
require 'spork/ext/ruby-debug'

Spork.prefork do
  # This file is copied to spec/ when you run 'rails generate rspec:install'
  ENV["RAILS_ENV"] ||= 'test'
  ENV['TWILIO_CALLBACK_HOST'] ||= 'test.com'
  ENV['CALL_END_CALLBACK_HOST'] ||= 'test.com'
  ENV['INCOMING_CALLBACK_HOST'] ||= 'test.com'
  ENV['VOIP_API_URL'] ||= 'test.com'
  ENV['TWILIO_CALLBACK_PORT'] ||= '80'
  ENV['RECORDING_ENV'] ||= 'test'
  ENV['CALLIN_PHONE'] ||= '5555551234'

  require File.expand_path("../../config/environment", __FILE__)
  require 'rspec/rails'
  require 'webmock/rspec'
  require 'spork/ext/ruby-debug'

  # Requires supporting ruby files with custom matchers and macros, etc,
  # in spec/support/ and its subdirectories.
  Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}
  Dir[Rails.root.join("spec/shared/**/*.rb")].each {|f| require f}
  #Dir[Rails.root.join("simulator/new_simulator.rb")].each {|f| require f}

  Capybara.javascript_driver = :webkit

  RSpec.configure do |config|
    config.include FactoryGirl::Syntax::Methods
    config.include TwilioRequestStubs

    config.before(:each) do
      $redis_call_flow_connection.flushALL
    end

    config.mock_with :rspec

    config.before(:suite) do
      WebMock.allow_net_connect!

      if ENV['RAILS_ENV'] == 'e2e'
        Capybara.javascript_driver = :webkit
        DatabaseCleaner.strategy = :truncation
      else
        DatabaseCleaner.strategy = :transaction
      end
      DatabaseCleaner.clean_with :truncation
    end

    config.after(:suite) do
      DatabaseCleaner.clean
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

    config.fixture_path = Rails.root.join('spec/fixtures')
  end

  include ActionDispatch::TestProcess

  def login_as(user)
    @controller.stub(:current_user).and_return(user)
    session[:user] = user.id
    session[:caller] = user.id
  end

  def http_login
    name = AdminController::USER_NAME
    password = AdminController::PASSWORD
    if page.driver.respond_to?(:basic_auth)
      page.driver.basic_auth(name, password)
    elsif page.driver.respond_to?(:basic_authorize)
      page.driver.basic_authorize(name, password)
    elsif page.driver.respond_to?(:browser) && page.driver.browser.respond_to?(:basic_authorize)
      page.driver.browser.basic_authorize(name, password)
    else
      raise "I don't know how to log in!"
    end
  end

  def create_user_and_login
    user = build :user
    visit '/client/login'
    fill_in 'Email address', :with => user.email
    fill_in 'Pick a password', :with => user.new_password
    click_button 'Sign up'
    click_button 'I and the company or organization I represent accept these terms.'
  end

  def web_login_as(user)
    visit '/client/login'
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password'
    click_on 'Log in'
  end

  def caller_login_as(caller)
    visit '/caller/login'
    fill_in 'Username', with: caller.username
    fill_in 'Password', with: caller.password
    click_on 'Log in'
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
