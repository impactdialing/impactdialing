require 'resque/plugins/lock'
require 'resque-loner'

class RedisToMysqlJob 
  extend Resque::Plugins::Lock
  include Resque::Plugins::UniqueJob
  @queue = :redis_to_mysql
  
  def self.perform
    
  end     
