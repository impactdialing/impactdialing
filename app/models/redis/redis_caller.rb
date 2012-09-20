require 'redis/hash_key'

class RedisCaller  
  include Redis::Objects
  

  def self.logged_in(campaign_id)
    Redis::SortedSet.new("campaign_id:#{campaign_id}:logged_in", $redis_dialer_connection)
  end
  
  
  def self.on_hold(campaign_id)
    Redis::SortedSet.new("campaign_id:#{campaign_id}:on_hold", $redis_dialer_connection)
  end
  
  def self.waiting_to_connect(campaign_id)
    Redis::SortedSet.new("campaign_id:#{campaign_id}:waiting_to_connect", $redis_dialer_connection)
  end
  
  def self.on_call(campaign_id)
    Redis::SortedSet.new("campaign:#{campaign_id}:on_call", $redis_dialer_connection)
  end
  
  def self.on_wrapup(campaign_id)
    Redis::SortedSet.new("campaign:#{campaign_id}:on_wrapup", $redis_dialer_connection)
  end
  
    
  def self.disconnected(campaign_id)
    Redis::SortedSet.new("campaign:#{campaign_id}:disconnected", $redis_dialer_connection)
  end
  
    
  def self.add_caller(campaign_id, caller_session_id)
    logged_in(campaign_id).add(caller_session_id, Time.now.to_i)
    on_hold(campaign_id).add(caller_session_id, Time.now.to_i)
  end
  
  def self.disconnect_caller(campaign_id, caller_session_id)
    zmove(on_hold(campaign_id), disconnected(campaign_id), Time.now.to_i, caller_session_id)
    zmove(waiting_to_connect(campaign_id), disconnected(campaign_id), Time.now.to_i, caller_session_id)
    zmove(on_call(campaign_id), disconnected(campaign_id), Time.now.to_i, caller_session_id)
    zmove(on_wrapup(campaign_id), disconnected(campaign_id), Time.now.to_i, caller_session_id)    
    logged_in(campaign_id).delete(caller_session_id)
  end
  
  def self.move_to_on_hold(campaign_id, caller_session_id)
    zmove(waiting_to_connect(campaign_id), on_hold(campaign_id), Time.now.to_i, caller_session_id)
    zmove(on_call(campaign_id), on_hold(campaign_id), Time.now.to_i, caller_session_id)
    zmove(on_wrapup(campaign_id), on_hold(campaign_id), Time.now.to_i, caller_session_id)    
  end
  
  
  def self.move_on_hold_waiting_to_connect(campaign_id, caller_session_id)
    zmove(on_hold(campaign_id), waiting_to_connect(campaign_id), Time.now.to_i, caller_session_id)
  end
  
  def self.move_waiting_to_connect_to_on_hold(campaign_id, caller_session_id)
    zmove(waiting_to_connect(campaign_id), on_hold(campaign_id), Time.now.to_i, caller_session_id)
  end
  
  def self.move_waiting_to_connect_to_on_call(campaign_id, caller_session_id)
    zmove(waiting_to_connect(campaign_id), on_call(campaign_id), Time.now.to_i, caller_session_id)
  end
  
  
  def self.move_on_hold_to_on_call(campaign_id, caller_session_id)
    zmove(on_hold(campaign_id), on_call(campaign_id), Time.now.to_i, caller_session_id)
  end
  
  
  
  def self.move_on_call_to_on_wrapup(campaign_id, caller_session_id)
    zmove(on_call(campaign_id), on_wrapup(campaign_id), Time.now.to_i, caller_session_id)
  end
  
  def self.move_on_wrapup_to_on_hold(campaign_id, caller_session_id)
    zmove(on_wrapup(campaign_id), on_hold(campaign_id), Time.now.to_i, caller_session_id)
  end
  
  def move_to_on_hold(campaign_id, caller_session_id)
    zmove(on_wrapup(campaign_id), on_hold(campaign_id), Time.now.to_i, caller_session_id)
    zmove(on_wrapup(campaign_id), on_hold(campaign_id), Time.now.to_i, caller_session_id)
  end
  
  def self.on_call?(campaign_id, caller_session_id)
    on_call(campaign_id).member?(caller_session_id)
  end
    
  
  def self.count(campaign_id)
    logged_in(campaign_id).length
  end
  
  def self.on_hold_count(campaign_id)
    on_hold(campaign_id).length
  end
  
  def self.zero?(campaign_id)
    count(campaign_id) == 0
  end
  
  def self.caller?(campaign_id, caller_session_id)
    logged_in(campaign_id).member?(caller_session_id)
  end
  
  def self.disconnected?(campaign_id, caller_session_id)
    disconnected(campaign_id).member?(caller_session_id)
  end
  
  
  def self.longest_waiting_caller(campaign_id)
    callers = on_hold(campaign_id).range(-1,-1)
    callers.empty? ? nil : callers.first
  end
  
  def self.stats(campaign_id)
    {callers_logged_in: logged_in(campaign_id).length, on_call: on_call(campaign_id).length, on_hold: on_hold(campaign_id).length, }
  end
  
  def self.zmove(set1, set2, score, element)
    $redis_dialer_connection.multi do
      set1.delete(element)
      set2.add(element, score)
    end
  end
  
    
end