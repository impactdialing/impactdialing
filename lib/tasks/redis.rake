namespace :redis do
  def redis
    @redis ||= Redis.new
  end

  desc "Update redis server config"
  task :update_config => [:environment] do
    redis.config(:set, 'hash-max-ziplist-entries', 1024)
    redis.config(:set, 'hash-max-ziplist-value', 1024)
  end

  desc "Purge archived campaign data from redis"
  task :purge_archived_campaigns => [:environment] do
    print "Purging data for #{Campaign.archived.count} campaigns\n"
    Campaign.archived.find_in_batches(batch_size: 500) do |campaigns|
      keys = []
      campaigns.each do |campaign|
        campaign.send(:inflight_stats).delete
        redis.del(RedisStatus.redis_key(campaign.id))
        redis.scan_each(match: "campaign_id:#{campaign.id}*") do |key|
          keys << key
        end
        keys.uniq.each do |key|
          redis.del(key)
        end
      end
    end
    print "\ndone\n"
  end

  desc "Purge deprecated redis keys"
  task :purge_deprecated_keys => [:environment] do
    lists = %w(not_answered_call_list abandoned_call_list
               end_answered_by_machine disconnected_call_list
              wrapped_up_call_list processing_by_machine_call_list)
    lists.each do |list|
      redis.del list, 0, 0
    end

    hashes = %w(message_dropped call_flow data_centre monitor)
    hashes.each do |hash|
      keys = []
      redis.scan_each(match: "#{hash}*") do |key|
        keys << key
      end
      keys.uniq.each do |key|
        redis.del(key)
      end
    end
  end

  desc "Delete cached Contact Fields for archived Scripts"
  task :delete_archived_script_caches => [:environment] do
    Script.where(active: false).each do |script|
      cache = CallFlow::Web::ContactFields::Selected.new(script)
      cache.delete
      RedisQuestion.clear_list(script.id)
      script.questions.each do |question|
        RedisPossibleResponse.clear_list(script_id)
      end
    end
  end
end

