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
      begin
        account = call_time.campaign.account
        subscription = account.debitable_subscription
        debit = Debit.new(call_time, account, subscription)
        results << debit.process
      rescue Exception => e
        UserMailer.new.deliver_exception_notification('DebitJob Exception', e)
      end
    end
    klass.import results, on_duplicate_key_update: [:debited]
  end

  def self.perform
    ActiveRecord::Base.verify_active_connections!

    CALL_TIME_CLASSES.each do |klass_name, limit|
      klass = klass_name.constantize
      call_times = klass.debit_pending.includes({campaign: :account}).limit(limit)
      Rails.logger.error "DebitJob: processing #{klass_name} #{call_times.count}"
      batch_process(klass, call_times)
    end
  end
end
