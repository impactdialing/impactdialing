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

  @queue = :background_worker

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
      results << debit.process
    end
    import_result = klass.import results, on_duplicate_key_update: [:debited]
  end

  def self.perform
    ActiveRecord::Base.verify_active_connections!

    CALL_TIME_CLASSES.each do |klass_name, limit|
      klass = klass_name.constantize
      call_times = klass.debit_pending.includes({campaign: :account}).limit(limit)
      batch_process(klass, call_times)
    end
  end
end
