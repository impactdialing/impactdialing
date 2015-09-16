namespace :migrate_redis do
  def queue_redis_migration_jobs(account_ids)
    account_ids.each do |account_id|
      SomeJob.enqueue(account_id)
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

  task :priority_accounts => [:environment] do
    account_ids = []
    queue_redis_migration_jobs(account_ids)
  end

  task :other_accounts => [:environment] do
    account_ids = [1318]
    queue_redis_migration_jobs(account_ids)
  end

  task :verify, [:campaign_id] => [:environment] do |t,args|
    require 'migrate_redis'
    redis = Redis.new
    campaign = Campaign.find args[:campaign_id]
    migration = MigrateRedis.new(campaign)
    campaign.households.each do |household|
      migration.import(household)
    end

    dial_queue = campaign.dial_queue
    
    dial_queue_blocked = redis.zcard("dial_queue:#{campaign.id}:blocked")
    blocked = campaign.blocked_numbers.size == dial_queue_blocked
    assert blocked, "BlockedNumbers[#{campaign.blocked_numbers.size}] BlockedZset[#{dial_queue_blocked}]"

    completed_sql = campaign.households.where(status: CallAttempt::Status::SUCCESS).to_a.select{|h| h.complete?}
    dial_queue_completed = redis.zcard("dial_queue:#{campaign.id}:completed")
    completed     = completed_sql.size == dial_queue_completed
    assert completed, "CompletedSQL[#{completed_sql.size}] CompletedZset[#{dial_queue_completed}]"

    failed_sql = campaign.households.failed.count
    dial_queue_failed = redis.zcard("dial_queue:#{campaign.id}:failed")
    failed     = failed_sql == dial_queue_failed
    assert failed, "FailedSQL[#{failed_sql}] FailedZset[#{dial_queue_failed}]"

    completed_sql.each do |household|
      hh = dial_queue.households.find household.phone
      assert_no_empty_leads(hh)
    end

    disabled_voters = VoterList.where(campaign_id: campaign.id).where(enabled: false).map(&:voters).flatten
    disabled_voters.each do |voter|
      base_key = "dial_queue:#{campaign.id}:households:inactive"
      key = "#{base_key}:#{voter.household.phone[0..-4]}"
      hkey = voter.household.phone[-3..-1]
      _hh = redis.hget key, hkey
      hh = _hh.blank? ? {'leads' => [{}]} : JSON.parse(_hh)
      assert_no_empty_leads(hh)

      hhactive = campaign.dial_queue.households.find voter.household.phone
      inactive_lead_ids = hh['leads'].map{|l| l['sql_id']}
      disabled_not_in_active = hh['leads'].detect?{|l| inactive_lead_ids.include?(l['sql_id'])}
      assert disabled_not_in_active.nil?, "DisabledInActive[#{disabled_not_in_active}] Household[#{voter.household.phone}] Campaign[#{campaign.id}]"
    end
  end
end

