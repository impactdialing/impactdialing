require 'resque-loner'
require 'librato_resque'

##
# Run periodically to deduct minutes used by +CallerSession+,
# +CallAttempt+ and +TransferAttempt+ from appropriate +Quota+.
#
# ### Metrics
#
# - completed
# - failed
# - timing
# - sql timing
#
# ### Monitoring
#
# Alert conditions:
#
# - 1 failure
# - OR stops reporting for 5 minutes
#
class DebitJob
  include Resque::Plugins::UniqueJob
  extend LibratoResque

  @loner_ttl = 150
  @queue = :billing

  CALL_TIME_CLASSES = {
    'CallerSession' => 1000,
    'CallAttempt' => 3000,
    'TransferAttempt' => 500
  }

  def self.batch_process(klass, call_times)
    results = []
    call_times.each do |call_time|
      account = call_time.campaign.account
      quota = account.quota

      debit = Debit.new(call_time, quota, account)
      updated_call_time = debit.process
      results << updated_call_time.attributes
    end
    klass.import_hashes(results, columns_to_update: [:debited])
  end

  def self.perform
    ActiveRecord::Base.clear_active_connections!

    CALL_TIME_CLASSES.each do |klass_name, limit|
      klass = klass_name.constantize
      call_times = klass.debit_pending.includes({campaign: :account}).limit(limit)
      batch_process(klass, call_times)
    end
  end
end
