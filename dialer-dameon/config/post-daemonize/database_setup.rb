#db_yaml = DaemonKit::Config.load('database')
#ActiveRecord::Base.establish_connection(db_yaml.to_h)
DaemonKit.logger.info "Setting up ActiveRecord Connection"
database_yaml = IO.read(File.join(File.dirname(__FILE__), '../../../config/database.yml'))
databases = YAML::load(database_yaml)
ActiveRecord::Base.establish_connection(databases[DaemonKit.env])

#memcached
#CACHE = MemCache.new 'localhost:11211'
#
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
# if DaemonKit.env=="development"
#   CACHE.servers = '127.0.0.1:11211'
# else
#
#   CACHE.servers = 'domU-12-31-39-10-89-26.compute-1.internal:11211'
#   begin
#      PhusionPassenger.on_event(:starting_worker_process) do |forked|
#        if forked
#          # We're in smart spawning mode, so...
#          # Close duplicated memcached connections - they will open themselves
#          CACHE.reset
#        end
#      end
#   # In case you're not running under Passenger (i.e. devmode with mongrel)
#   rescue NameError => error
#   end
# end
