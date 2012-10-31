class RedisDataCentre
  
  def self.set_datacentres_used(campaign_id, datacentre)
    $redis_dialer_connection.lpush 'data_centre:#{campaign_id}', datacentre
  end
  
  def self.data_centres(campaign_id)
    dcs = $redis_dialer_connection.lrange 'data_centre:#{campaign_id}', 0, -1    
    dcs.uniq.join(",")
  end
  
  def self.remove_data_centre(campaign_id, data_centre)
    $redis_dialer_connection.lrem 'data_centre:#{campaign_id}', 1, data_centre
  end
  
  def self.add_to_voxeo_dc_campaigns(campaign_id)
    campaign_set = Redis::Set.new("voxeo", $redis_dialer_connection)
    campaign_set << campaign_id if Campaign.predictive_campaign?(type)
  end
  
  def self.add_to_twilio_dc_campaigns
    campaign_set = Redis::Set.new("twilio", $redis_dialer_connection)
    campaign_set << campaign_id    
  end
  
  
  
end