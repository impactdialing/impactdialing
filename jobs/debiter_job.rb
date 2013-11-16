require 'resque-loner'

class DebiterJob
  include Resque::Plugins::UniqueJob
  @queue = :background_worker

  def self.debit(records)
    results = []
    records.each do |record|
      begin
        results << record.debit
      rescue Exception => e
        UserMailer.new.deliver_exception_notification('DebiterJob Exception', e)
      end
    end
    records.first.class.import results, on_duplicate_key_update: [:debited, :payment_id]
  end

  def self.perform
    ActiveRecord::Base.verify_active_connections!

    CallAttempt.debit_not_processed.find_in_batches do |call_attempts|
      debit(call_attempts)
    end

    CallerSession.debit_not_processed.find_in_batches do |caller_sessions|
      debit(caller_sessions)
    end

    TransferAttempt.debit_not_processed.find_in_batches do |transfer_attempts|
      debit(transfer_attempts)
    end
  end
end
