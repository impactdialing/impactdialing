module OctopusConnection
  extend self
  def connection(shard = :master)
    return ActiveRecord::Base.connection
  end

  def dynamic_shard(*shards)
    shards.sample
  end
end
