require 'resque-loner'

class DebitJob
  include Resque::Plugins::UniqueJob
  @queue = :background_worker

  CALL_TIME_CLASSES = {
    'CallerSession' => 2000,
    'CallAttempt' => 1000,
    'TransferAttempt' => 500
  }

  def self.batch_process(klass, call_times)
    results = []
    call_times.each do |call_time|
      account = call_time.campaign.account
      subscription = account.debitable_subscription
      # debug
      before = [subscription.minutes_utlized, subscription.available_minutes]

      debit = Debit.new(call_time, account, subscription)
      results << debit.process

      # debug
      after = [subscription.minutes_utlized, subscription.available_minutes]
      # debug
      unless call_time.debited
        m = (call_time.tDuration/60.0).ceil
        d = call_time.debited
        Rails.logger.error "DebitJob: Account[#{account.id}] Sub[#{subscription.id}] #{klass}[#{call_time.id}] Before[#{before[0]}:#{before[1]}] After[#{after[0]}:#{after[1]}] CallTimeMinutes[#{m}] CallTimeDebited[#{d}]"
      end
    end
    import_result = klass.import results, on_duplicate_key_update: [:debited]
    # debug
    Rails.logger.error "DebitJob: Inserts[#{import_result.num_inserts}] Failed[#{import_result.failed_instances.size}]"
  end

  def self.perform
    ActiveRecord::Base.verify_active_connections!

    CALL_TIME_CLASSES.each do |klass_name, limit|
      klass = klass_name.constantize
      call_times = klass.debit_pending.includes({campaign: :account}).limit(limit)
      Rails.logger.error "DebitJob: processing #{klass_name} #{call_times.count} - #{call_times.first.try(:id)} thru #{call_times.last.try(:id)}"
      batch_process(klass, call_times)
    end
  end
end
