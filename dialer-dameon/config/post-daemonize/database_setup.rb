#db_yaml = DaemonKit::Config.load('database') 
#ActiveRecord::Base.establish_connection(db_yaml.to_h)
DaemonKit.logger.info "Setting up ActiveRecord Connection" 
if DaemonKit.env=="development"
  database_yaml = IO.read('/Volumes/MacHD/Users/blevine/dev/impact_dialing/config/database.yml')
else
  database_yaml = IO.read('/var/www/html/trunk/config/database.yml')
end
databases = YAML::load(database_yaml)
ActiveRecord::Base.establish_connection(databases["development"])

#memcached
CACHE = MemCache.new 'localhost:11211'