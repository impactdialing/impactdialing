source :rubygems

gem 'rails', '3.0.10'
gem 'unicorn'
gem 'will_paginate', '~> 2.3.11'
gem 'mysql', '~> 2.8.1'
gem 'memcache-client', '~> 1.8.5', :require => 'memcache'
gem 'fastercsv', '~> 1.5.4'
gem 'newrelic_rpm'
gem 'hoptoad_notifier', '~> 2.4.11'
gem 'json', '~> 1.6.1'
gem 'nokogiri', '~> 1.4.4'
gem "activemerchant", '~> 1.15.0', :require => "active_merchant"
gem 'hpricot', '~> 0.8.4'
gem 'uakari', '~> 0.2.0'
gem "pusher", "~> 0.9.2"
gem "aws-s3", "~> 0.6.2", :require => "aws/s3"
gem "paperclip", "2.3.16"
gem 'daemons', '~> 1.0.10'
gem 'twilio', '~> 3.0.1'
gem 'settingslogic', '~> 2.0.6'
gem "twilio-ruby", '~> 3.5.1'
gem 'dynamic_form', '~> 1.1.4'
gem 'in_place_editing', '~> 1.1.1'
gem "nested_form", '~>0.1.1'
gem 'rspec'
gem 'jquery-rails', '>= 1.0.12'
gem 'delayed_job', '~>2.1.4'
gem 'heroku'
gem "activerecord-import", ">= 0.2.0"
gem 'rush', '>= 0.0.6'
gem 'workless'
gem "airbrake"
gem "uuid", "~> 2.3.5"
gem 'recurly', '~> 2.0.11'
gem "hiredis", "~>0.4.5"
gem "redis", "~>2.2.2"
gem "em-http-request", "~>0.3.0"


group :development, :test do
  gem 'ruby-debug19'
  gem 'rspec-rails', '~> 2.6.1'
end

group :development do
  gem 'thin'
  gem 'guard'
  gem 'guard-bundler'
  gem 'guard-rspec'
  gem 'guard-spork'
  gem 'guard-rails'
  gem 'capistrano', '2.9.0'
  gem 'heroku_san'
end


# run 'bundle install' with either '--without linux' or '--without darwin' depending on your os.
# you only need to do this once since the options will be saved in your .bundle/config file for subsequent calls
group :darwin do #mac notifiers
  gem 'rb-fsevent'
#  gem 'growl_notify'
end

group :linux do #linux notifiers
  gem 'rb-inotify'
  gem 'libnotify'
end

group :test do
  gem 'factory_girl', '~> 1.3.3'
  gem 'shoulda', '~> 2.11.3'
  gem 'simplecov'
  gem 'spork', '~> 0.9.0.rc9'
end
