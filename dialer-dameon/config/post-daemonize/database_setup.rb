#db_yaml = DaemonKit::Config.load('database') 
#ActiveRecord::Base.establish_connection(db_yaml.to_h)
DaemonKit.logger.info "Setting up ActiveRecord Connection" 
database_yaml = IO.read('/Volumes/MacHD/Users/blevine/dev/impactdialing/config/database.yml')
databases = YAML::load(database_yaml)
ActiveRecord::Base.establish_connection(databases["development"])

#memcached
CACHE = MemCache.new 'localhost:11211'