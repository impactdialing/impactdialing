require 'resque-loner'

class DebitJob
  include Resque::Plugins::UniqueJob
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
    metrics = ImpactPlatform::Metrics::JobStatus.started(self.to_s.underscore)

    ActiveRecord::Base.verify_active_connections!

    CALL_TIME_CLASSES.each do |klass_name, limit|
      klass = klass_name.constantize
      call_times = klass.debit_pending.includes({campaign: :account}).limit(limit)
      batch_process(klass, call_times)
    end

    metrics.completed
  end
end
