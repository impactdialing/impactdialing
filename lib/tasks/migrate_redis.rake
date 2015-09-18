namespace :migrate_redis do
  def queue_redis_migration_jobs(account_ids)
    accounts = Account.where(id: account_ids)
    accounts.each do |account|
      account.campaigns.each do |campaign|
        campaign.households.select(:id).find_in_batches do |households|
          households.each do |household|
            MigrateRedisData.perform_async(account.id, campaign.id, household.id)
          end
        end
      end
    end
  end

  def assert(val, msg)
    if val
      print '.'
    else
      print "\n"
      p msg
    end
  end

  def assert_no_empty_leads(hh)
    o = []
    hh['leads'].each do |lead|
      o << lead['uuid'].present? and lead['sql_id'].present? and lead['account_id'].present? and lead['campaign_id'].present?
    end
    assert o.size == hh['leads'].size, "EmptyLeads[#{hh['leads'].size - o.size}] Leads[#{hh['leads'].size}]"
  end

  task :all_accounts => [:environment] do
    account_ids = Campaign.active.pluck(:account_id)
    queue_redis_migration_jobs(account_ids)
  end

  task :priority_accounts => [:environment] do
    account_ids = [1427, 1353, 1418, 1424, 1430]
    queue_redis_migration_jobs(account_ids)
  end

  task :other_accounts => [:environment] do
    account_ids = Campaign.active.pluck(:account_id) - [1318]
    account_ids += [1318]
    queue_redis_migration_jobs(account_ids)
  end

  task :verify, [:campaign_id] => [:environment] do |t,args|
    require 'migrate_redis'
    redis = Redis.new
    campaign = Campaign.find args[:campaign_id]

    dial_queue = campaign.dial_queue

    err_msg = "CampaignID[#{campaign.id}] Campaign[#{campaign.name}]"
    
    dial_queue_blocked = redis.zcard("dial_queue:#{campaign.id}:blocked")
    dnc = campaign.households.with_blocked(:dnc).count
    cell = campaign.households.with_blocked(:cell).count
    blocked = (cell + dnc) == dial_queue_blocked
    if campaign.all_voters.with_enabled(:list).count.zero?
      # no active leads, so no numbers should be in zset
      blocked = true
    end
    assert blocked, "#{err_msg} BlockedNumbers[#{dnc + cell}] BlockedZset[#{dial_queue_blocked}]"

    completed_sql = campaign.households.where('status != "not called"').to_a.select do |h|
      h.complete? and h.voters.with_enabled(:list).count > 0
    end
    dial_queue_completed = redis.zcard("dial_queue:#{campaign.id}:completed")
    completed     = completed_sql.size == dial_queue_completed
    assert completed, "#{err_msg} CompletedSQL[#{completed_sql.size}] CompletedZset[#{dial_queue_completed}]"

    failed_sql = campaign.households.failed.count
    dial_queue_failed = redis.zcard("dial_queue:#{campaign.id}:failed")
    failed     = failed_sql == dial_queue_failed
    assert failed, "#{err_msg} FailedSQL[#{failed_sql}] FailedZset[#{dial_queue_failed}]"

    completed_sql.each do |household|
      if household.voters.any?{|v| v.enabled?(:list)}
        _hh = redis.hget("dial_queue:#{campaign.id}:households:active:#{household.phone[0..-4]}", household.phone[-3..-1])
        hh = _hh.present? ? JSON.parse(_hh) : {'leads' => []}
        assert_no_empty_leads(hh)
      end
      if household.voters.any?{|v| not v.enabled?(:list)}
        _hh = redis.hget("dial_queue:#{campaign.id}:households:inactive:#{household.phone[0..-4]}", household.phone[-3..-1])
        hh = _hh.present? ? JSON.parse(_hh) : {'leads' => []}
        assert_no_empty_leads(hh)
      end
    end

    disabled_voters = VoterList.where(campaign_id: campaign.id).where(enabled: false).map(&:voters).flatten
    disabled_voters.each do |voter|
      base_key = "dial_queue:#{campaign.id}:households:inactive"
      key = "#{base_key}:#{voter.household.phone[0..-4]}"
      hkey = voter.household.phone[-3..-1]
      _hh = redis.hget key, hkey
      hh = _hh.blank? ? {'leads' => [{}]} : JSON.parse(_hh)
      assert_no_empty_leads(hh)

      k = key.gsub('inactive','active')
      _hhactive = redis.hget(k, hkey)
      hhactive = _hhactive.blank? ? {'leads' => [{}]} : JSON.parse(_hhactive)
      inactive_lead_ids = hh['leads'].map{|l| l['sql_id']}
      if hhactive.empty?
        disabled_not_in_active = nil
      else
        disabled_not_in_active = hhactive['leads'].detect{|l| inactive_lead_ids.include?(l['sql_id'])}
      end
      assert disabled_not_in_active.nil?, "#{err_msg} DisabledInActive[#{disabled_not_in_active}] Household[#{voter.household.phone}] Campaign[#{campaign.id}]"
    end
  end
end

