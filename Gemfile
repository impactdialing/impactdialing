source 'https://rubygems.org'

ruby '2.0.0'

gem 'rails', '~> 3.2.13'
gem 'unicorn'
gem 'thin', "~> 1.5.1"
gem 'will_paginate', '~> 3.0'
gem 'mysql2', '~> 0.3.11'
gem 'newrelic_rpm'
gem 'json', '~> 1.7.7'
gem 'nokogiri', '~> 1.6.0'
gem "pusher", "~> 0.11.3"
gem "aws-sdk"
gem "paperclip", "~> 3.4.2"
gem 'twilio', '~> 3.1.1'
gem 'settingslogic', '~> 2.0.9'
gem "twilio-ruby", '~> 3.10.0'
gem 'dynamic_form', '~> 1.1.4'
gem 'jquery-rails', '>= 1.0.12'
gem "activerecord-import", ">= 0.3.1"
gem 'recurly', '~> 2.1.3'
gem "heroku"
gem "uuid", "~> 2.3.5"
gem "eventmachine", "1.0.3"
gem "em-http-request", "1.0.3"
gem "em-synchrony", "~> 1.0.3"
gem "resque", "~> 1.24.1"
gem "resque-scheduler", "~> 2.0.1", :require => 'resque_scheduler'
gem 'resque-lock', "~> 1.1.0"
gem "resque-loner", "~>1.2.1"
gem "hiredis", "~>0.4.5"
gem "em-hiredis", "~>0.2.1"
gem "formtastic", "~>2.2.1"
gem "cocoon", "~>1.0.22"
gem 'deep_cloneable', '~> 1.5.2'
gem "redis-objects", "~>0.7.0",:require => 'redis/objects'
gem "redis", "~> 3.0.4"
gem 'ar-octopus', :git => "git://github.com/tchandy/octopus.git"
gem "newrelic-redis", "~>1.3.2"
gem "sidekiq", "~> 2.13.0"
gem "slim", "~>2.0.0"
gem "sprockets", "~>2.2.1"
gem "sinatra", "~>1.3.3"
gem "dalli", "~>2.3.0"
gem "mandrill-api", "~>1.0.37"
gem "sidekiq-failures", "~> 0.1.0"
gem "lograge", "~>0.2.0"
gem "pry"


group :development, :test do
  gem 'rspec', "~>2.6.0"
  gem 'rspec-rails', '~> 2.6.1'
  gem 'debugger', "~>1.6.0"
  gem 'hirb', "~>0.7.1"
  gem 'rspec-instafail', "~>0.2.4"
end

group :development do
  gem 'guard', "~>1.6.2"
  gem 'guard-rspec', "~>1.2.1"
  gem 'guard-spork', "~>1.5.0"
  gem 'rb-fsevent', "~>0.9.3"
  gem 'showoff-io', "~>0.4.0"
  gem 'foreman', "~>0.62.0"
  gem "capistrano"
  gem "capistrano_colors"
  gem "capistrano-multiconfig"
  gem "pusher-fake", "~>0.9.0"
  gem "better_errors", "~>0.7.2"
  gem "binding_of_caller", "~>0.7.1"
end

group :test, :integration_test do
  gem 'factory_girl', '~> 1.3.3'
  gem 'shoulda', "~>3.3.2"
  gem 'simplecov', "~>0.7.1"
  gem 'spork-rails', "~>3.2.1"
  gem "database_cleaner", "~>0.9.1"
  gem "json_spec", "~>1.1.0"
  gem 'selenium-webdriver', "~>2.34"
  gem "capybara", "~>2.1.0"
  gem 'launchy', "~>2.2.0"
  gem "pusher-fake", "~>0.9.0"
  gem "faraday"
  gem "forward"
end