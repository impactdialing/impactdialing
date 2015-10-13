source 'https://rubygems.org'

ruby '2.0.0'

gem 'rails', '~> 4.0.0'
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'puma'
gem 'rack-timeout'

# heroku
gem 'rails_12factor', group: :production
gem 'hirefire-resource'

# resque/sidekiq -web
gem 'sinatra'
gem 'slim'


gem 'uuid', '~> 2.3.7' # used to generate unique filenames for download reports - overkill much?

# 911
gem 'pagerduty'
gem 'bugsnag'

# ActiveRecord extensions
gem 'upsert'
gem 'activerecord-import'
gem 'ar-octopus'
gem 'bitmask_attributes'
gem 'will_paginate'
gem 'deep_cloneable'

# Auth/z
gem 'cancan', '~>1.6.10'

# Background
gem 'resque', '~> 1.24.1'
gem 'resque-scheduler', '~> 2.0.1', :require => 'resque_scheduler'
gem 'rufus-scheduler', '~> 2.0.0'
gem 'resque-lock', '~> 1.1.0'
gem 'resque-loner', '~>1.2.1'
gem 'sidekiq', '< 3'

# Databases
gem 'mysql2'
gem 'redis', '~> 3.1.0'
gem 'redis-objects', '~>0.7.0',:require => 'redis/objects'
gem 'hiredis', '~>0.4.5'
gem 'em-hiredis', '~>0.2.1'

# DNS
gem 'em-resolv-replace' # non-blocking lookups for eventmachine

# EventMachine
gem 'eventmachine', '1.0.3'
gem 'em-http-request', '~> 1.1.0'
gem 'em-synchrony', '~> 1.0.3'

# Files
gem 'paperclip'
gem 'rubyzip'

# Forms
gem 'formtastic', '~>2.2.1'
gem 'dynamic_form', '~> 1.1.4'
gem 'cocoon', '~> 1.2.0'

# HTTP client
gem 'faraday'
gem 'faraday_middleware'
gem 'faraday-cookie_jar'

# Logging
gem 'lograge', '~>0.2.0'

# Reporting
gem 'ruport'
gem 'acts_as_reportable'

# Text -> HTML processors
gem 'redcarpet'

# Provider clients
gem 'aws-sdk', '~> 1.6'
gem 'platform-api'
gem 'pusher', '~> 0.11.3'
gem 'stripe', '~>1.8.4'
gem 'twilio', '~> 3.1.1'
gem 'twilio-ruby', '~> 3.16.0'

# SMTP
gem 'mandrill-api', '~>1.0.37'

# Monitoring
gem 'librato-rails'
group :production, :heroku, :heroku_staging do
  gem 'rack-timing'
end

# redis lua scripts
gem 'wolverine'

group :development do
  gem 'annotate'
  gem 'spring'
  gem 'spring-commands-rspec'
  gem 'rb-fsevent'
  gem 'showoff-io'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'bullet'
end

group :development, :test, :e2e do
  gem 'rspec-rails'
  gem 'rspec-its' # its is not in rspec 3
  gem 'rspec-collection_matchers' # expect(collection).to have(1).thing is not in rspec 3
  gem 'forgery', '0.6.0'
  gem 'hirb'
  gem 'pry'
  gem 'byebug'
  gem 'compass'
end

group :test, :e2e do
  gem 'factory_girl_rails'
  gem 'shoulda'
  gem 'simplecov', require: false
  gem 'database_cleaner'
  gem 'capybara'
  gem 'launchy'
  gem 'timecop'
  gem 'webmock'
  gem 'vcr'
  gem 'selenium-webdriver'
  gem 'capybara-webkit'
end
