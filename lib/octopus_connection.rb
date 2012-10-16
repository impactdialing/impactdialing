module OctopusConnection
  extend self
  def connection(shard = :master)
    return ActiveRecord::Base.connection unless Octopus.enabled?
    ActiveRecord::Base.using(shard).connection.select_connection
  end
end
