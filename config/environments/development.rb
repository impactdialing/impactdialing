TWILIO_ACCOUNT="ACc0208d4be3e204d5812af2813683243a"
TWILIO_AUTH="4e179c64daa7c9f5108bd6623c98aea6"
#APP_NUMBER="5104048117"
APP_NUMBER="8583673996"
APP_URL="http://www.hinodae.com:5555"

# Settings specified here will take precedence over those in config/environment.rb

# In the development environment your application's code is reloaded on
# every request.  This slows down response time but is perfect for development
# since you don't have to restart the webserver when you make code changes.
config.cache_classes = false

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_view.debug_rjs                         = true
config.action_controller.perform_caching             = false

# Don't care if the mailer can't send
config.action_mailer.raise_delivery_errors = false

#require 'memcached_fix.rb'


# memcache_options = {
#   :c_threshold => 10000,
#   :compression => true,
#   :debug => false,
#   :namespace => 'some_ns',
#   :readonly => false,
#   :urlencode => false
# }
#  
# CACHE = MemCache.new memcache_options
# CACHE.servers = '127.0.0.1:11211'
