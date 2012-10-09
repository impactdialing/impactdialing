class RedisCampaignCall
  include Redis::Objects
  
  def self.ringing(campaign_id)
    Redis::SortedSet.new("campaign:#{campaign_id}:ringing", $redis_dialer_connection)    
  end
  
  def self.inprogress(campaign_id)
    Redis::SortedSet.new("campaign:#{campaign_id}:inprogress", $redis_dialer_connection)    
  end
  
  def self.abandoned(campaign_id)
    Redis::SortedSet.new("campaign:#{campaign_id}:abandoned", $redis_dialer_connection)    
  end    
  
  def self.wrapup(campaign_id)
    Redis::SortedSet.new("campaign:#{campaign_id}:wrapup", $redis_dialer_connection)    
  end
  
  def self.completed(campaign_id)
    Redis::SortedSet.new("campaign:#{campaign_id}:completed", $redis_dialer_connection)    
  end    
  
  def self.add_to_ringing(campaign_id, call_attempt_id)
    ringing(campaign_id).add(call_attempt_id, Time.now.to_i)
  end
  
  def self.move_ringing_to_inprogress(campaign_id, call_attempt_id)
    zmove(ringing(campaign_id), inprogress(campaign_id), Time.now.to_i, call_attempt_id)
  end
  
  def self.move_inprogress_to_wrapup(campaign_id, call_attempt_id)
    zmove(inprogress(campaign_id), wrapup(campaign_id), Time.now.to_i, call_attempt_id)
  end
  
  
  def self.move_ringing_to_abandoned(campaign_id, call_attempt_id)
    zmove(ringing(campaign_id), abandoned(campaign_id), Time.now.to_i, call_attempt_id)
  end
  
  def self.move_ringing_to_completed(campaign_id, call_attempt_id)
    zmove(ringing(campaign_id), completed(campaign_id), Time.now.to_i, call_attempt_id)
  end
  
  
  def self.move_wrapup_to_completed(campaign_id, call_attempt_id)
    zmove(wrapup(campaign_id), completed(campaign_id), Time.now.to_i, call_attempt_id)
  end
  
  def self.above_average_inprogress_calls_count(campaign_id, average_call_length)
    inprogress(campaign_id).rangebyscore((Time.now.to_i-average_call_length-15), (Time.now.to_i-average_call_length)).length
  end
  
  def self.above_average_wrapup_calls_count(campaign_id, average_wrapup_length)
    wrapup(campaign_id).rangebyscore((Time.now.to_i-average_wrapup_length-15), (Time.now.to_i-average_wrapup_length)).length
  end
  
  def self.ringing_last_20_seconds(campaign_id)
    ringing(campaign_id).rangebyscore((Time.now - 20.seconds).to_i, Time.now.to_i).length
  end
  
  def self.wrapup_last_30_seconds(campaign_id)
    wrapup(campaign_id).rangebyscore((Time.now - 30.seconds).to_i, Time.now.to_i).length
  end
  
  
  def self.stats(campaign_id)
    {ringing_lines: ringing_last_20_seconds(campaign_id), wrapup: wrapup(campaign_id).length, live_lines: inprogress(campaign_id).length}
  end
  
  
  def self.zmove(set1, set2, score, element)
    $redis_dialer_connection.multi do
      set1.delete(element)
      set2.add(element, score)
    end
  end
    
end