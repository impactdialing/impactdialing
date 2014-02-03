module Platform
  module MySQL
    def self.connect(pool_size)
      rails_config = Rails.application.config.database_configuration[Rails.env]
      rails_config['pool'] = pool_size || 5

      octopus_config = Octopus.config[Rails.env]
      octopus_config.each do |shard_name, shard_config|
        shard_config['pool'] = pool_size || 5
      end

      shards = ActiveRecord::Base.connection_proxy.instance_variable_get(:@shards)
      shards.each do |k,v|
        v.clear_reloadable_connections!
      end
    end

    def self.disconnect!
      ActiveRecord::Base.connection_pool.disconnect!
    end

    def self.reconnect!(pool_size)
      disconnect!
      connect(pool_size)
    end
  end
end