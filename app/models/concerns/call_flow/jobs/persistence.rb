class CallFlow::Jobs::Persistence
  include Sidekiq::Worker

  attr_reader :dialed_call, :campaign, :household_record

  sidekiq_options({
    queue: :persistence,
    retry: true,
    failures: true,
    backtrace: true
  })

  def perform(type, *args)
    klass = "CallFlow::Persistence::Call::#{type}".constantize
    klass.new(*args)
    klass.persist_call_outcome
  end
end

