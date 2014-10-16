source 'https://rubygems.org'

ruby '2.0.0'

gem 'rails', '~> 3.2.19'
gem 'unicorn'
gem 'will_paginate', '~> 3.0.4'
gem 'mysql2', '~> 0.3.13'
gem 'newrelic_rpm'
gem 'json', '~> 1.7.7'
gem 'nokogiri', '~> 1.6.0'
gem 'pusher', '~> 0.11.3'
gem 'aws-sdk'
gem 'paperclip', '~> 3.5.0'
gem 'twilio', '~> 3.1.1'
gem 'settingslogic', '~> 2.0.9'
gem 'twilio-ruby', '~> 3.10.0'
gem 'dynamic_form', '~> 1.1.4'
gem 'jquery-rails', '~> 3.0.4'
gem 'activerecord-import', '~> 0.4.1'
gem 'uuid', '~> 2.3.7'
gem 'eventmachine', '1.0.3'
gem 'em-http-request', '~> 1.1.0'
gem 'em-synchrony', '~> 1.0.3'
gem 'resque', '~> 1.24.1'
gem 'resque-scheduler', '~> 2.0.1', :require => 'resque_scheduler'
gem 'resque-lock', '~> 1.1.0'
gem 'resque-loner', '~>1.2.1'
gem 'hiredis', '~>0.4.5'
gem 'em-hiredis', '~>0.2.1'
gem 'formtastic', '~>2.2.1'
gem 'cocoon', '~>1.0.22'
gem 'deep_cloneable', '~> 1.5.3'
gem 'redis-objects', '~>0.7.0',:require => 'redis/objects'
gem 'redis', '~> 3.0.4'
gem 'ar-octopus', :git => 'git://github.com/tchandy/octopus.git'
gem 'newrelic-redis'
gem 'sidekiq', '~> 2.13.0'
gem 'slim', '~>2.0.0'
gem 'sprockets', '~>2.2.1'
gem 'sinatra', '~>1.4.3'
gem 'mandrill-api', '~>1.0.37'
gem 'sidekiq-failures', '~> 0.2.1'
gem 'lograge', '~>0.2.0'
gem 'cancan', '~>1.6.10'

# REST clients
gem 'stripe', '~>1.8.4'
gem 'platform-api'

# monitoring
group :production, :heroku, :heroku_staging do
  gem 'librato-rails'
  gem 'rack-timing'
  gem 'rack-queue-metrics', git: "https://github.com/heroku/rack-queue-metrics.git", branch: "cb-logging"
end

# Text -> HTML processors
gem 'redcarpet'

# Reporting
gem 'ruport'
gem 'acts_as_reportable'

# Non-blocking DNS look-ups for EventMachine
gem 'em-resolv-replace'

group :development do
  gem 'annotate'
  gem 'guard'
  gem 'guard-rspec'
  gem 'spring'
  gem 'spring-commands-rspec'
  gem 'rb-fsevent'
  gem 'showoff-io'
  gem 'foreman'
  gem 'capistrano'
  gem 'capistrano_colors'
  gem 'capistrano-multiconfig'
  gem 'better_errors'
  gem 'binding_of_caller'
end

group :development, :heroku_staging do
  gem 'bullet'
end

group :development, :test, :e2e do
  gem 'rspec-rails'
  gem 'rspec-its' # its is not in rspec 3
  gem 'rspec-activemodel-mocks' # mock_model is not in rspec 3
  gem 'rspec-collection_matchers' # expect(collection).to have(1).thing is not in rspec 3
  gem 'forgery', '0.6.0'
  gem 'hirb'
  gem 'rspec-instafail'
  gem 'pry'
  gem 'pry-debugger'
  gem 'compass'
  # cli tool to reload app when files change, whether background, web, initializer, etc
  # usage e.g. rerun foreman start
  gem 'rerun'
end

group :test, :e2e do
  gem 'factory_girl_rails'
  gem 'shoulda'
  gem 'simplecov'
  gem 'database_cleaner'
  gem 'capybara'
  gem 'launchy'
  gem 'timecop'
  gem 'webmock'
  gem 'capybara-webkit'
end
