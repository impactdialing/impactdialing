require 'uri'

module ImpactPlatform
  module MySQL
    def self.connect(pool_size=5)
      STDOUT.puts "MySQL.connect(#{pool_size})"
      rails_config = Rails.application.config.database_configuration[Rails.env]
      rails_config['pool'] = pool_size

      octopus_config = Octopus.config[Rails.env]
      octopus_config.each do |shard_name, shard_config|
        shard_config['pool'] = pool_size
      end

      database_url = ENV['DATABASE_URL']
      if database_url
        pool_query   = "pool=#{pool_size}"
        database_uri = URI.parse(database_url)
        if database_uri.query.nil?
          database_uri.query = pool_query
        else
          database_uri.query = database_uri.query + "&#{pool_query}"
        end
        ENV['DATABASE_URL'] = database_uri.to_s
      end

      shards = ActiveRecord::Base.connection_proxy.instance_variable_get(:@shards)
      shards.each do |k,v|
        v.clear_reloadable_connections!
      end
    end

    def self.disconnect!
      STDOUT.puts "MySQL.disconnect!"
      ActiveRecord::Base.connection_pool.disconnect!
    end

    def self.reconnect!(pool_size)
      disconnect!
      connect(pool_size)
    end
  end
end