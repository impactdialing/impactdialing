class CallFlow::Jobs::Persistence
  include Sidekiq::Worker

  attr_reader :campaign, :household_record, :type, :args

  sidekiq_options({
    queue: :persistence,
    retry: true,
    failures: true,
    backtrace: true
  })

  def perform(type, *args)
    @type = type
    @args = args
    target_call_persistence.persist_call_outcome
  end

  def target_call_persistence
    @target_call_persistence ||= case type
                                 when 'Completed'
                                   completed_call_persistence
                                 when 'Failed'
                                   failed_call_persistence
                                 else
                                   raise CallFlow::BaseArgumentError, "Unknown call type: #{type}"
                                 end
  end

  def completed_call_persistence
    @completed_call_persistence ||= CallFlow::Persistence::Call::Completed.new(*args)
  end

  def failed_call_persistence
    @failed_call_persistence ||= CallFlow::Persistence::Call::Failed.new(*args)
  end
end

