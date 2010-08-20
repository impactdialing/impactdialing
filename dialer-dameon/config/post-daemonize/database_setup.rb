#db_yaml = DaemonKit::Config.load('database') 
#ActiveRecord::Base.establish_connection(db_yaml.to_h)
DaemonKit.logger.info "Setting up ActiveRecord Connection" 
if DaemonKit.env=="development"
  database_yaml = IO.read('/Volumes/MacHD/Users/blevine/dev/impact_dialing/config/database.yml')
  ActiveRecord::Base.establish_connection(databases["development"])
else
  database_yaml = IO.read('/var/www/html/trunk/config/database.yml')
  ActiveRecord::Base.establish_connection(databases["production"])
end
databases = YAML::load(database_yaml)

#memcached
CACHE = MemCache.new 'localhost:11211'