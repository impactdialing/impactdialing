namespace :migrate_redis do
  def queue_redis_migration_jobs(account_ids)
    account_ids.each do |account_id|
      SomeJob.enqueue(account_id)
    end
  end

  task :priority_accounts => [:environment] do
    account_ids = []
    queue_redis_migration_jobs(account_ids)
  end

  task :other_accounts => [:environment] do
    account_ids = [1318]
    queue_redis_migration_jobs(account_ids)
  end
end

