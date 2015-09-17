require 'migrate_redis'

class MigrateRedisData
  include Sidekiq::Worker

  sidekiq_options queue: :migrations, retry: false

  def perform(account_id, campaign_id, household_id)
    campaign = Campaign.find campaign_id
    household = campaign.households.find household_id
    migration = MigrateRedis.new(campaign)
    migration.import(household)
  end
end
