namespace :dial_queue do
  namespace :inflight_stats do
    def inflight_stats
      redis    = Redis.new
      base_key = "inflight_stats"
      keys     = redis.keys "#{base_key}:*"
      stats    = []

      redis.scan_each(match: "#{base_key}:*") do |key|
        id = key.split(':')[1].to_i
        dqakey = ['dial_queue', id, 'active'].join(':')
        dqpkey = ['dial_queue', id, 'presented'].join(':')
        dqrkey = ['dial_queue', id, 'bin'].join(':')
        stats << [
          id, redis.hget(key, 'ringing'), redis.hget(key, 'presented'),
          redis.zcard(dqakey), redis.zcard(dqpkey), redis.zcard(dqrkey)
        ]
      end

      return stats
    end

    def print_inflight_stats
      print "Campaign,Ringing count,Presented count,DQ Available,DQ Presented,DQ Bin\n"
      print inflight_stats.map{|row| row.join(',')}.join("\n") + "\n"
    end

    desc "Generate CSV report of current inflight_stats"
    task :report => [:environment] do
      print_inflight_stats
    end

    desc "Reset all inflight stats to zero"
    task :reset,[:campaign_id] => [:environment] do |t,args|
      print "BEFORE\n"
      print_inflight_stats
      print "-----\n"
      campaign_id = args[:campaign_id]
      redis       = Redis.new
      base_key    = "inflight_stats"
      hash_args   = [:ringing, 0, :presented, 0]

      if campaign_id.present?
        key = [base_key, campaign_id].join(':')
        redis.hmset(key, *hash_args)
      else
        inflight_stats.each do |campaign_stats|
          key = [base_key, campaign_stats[0]].join(':')
          redis.hmset(key, *hash_args)
        end
      end
      print "AFTER\n"
      print_inflight_stats
    end
  end
end
