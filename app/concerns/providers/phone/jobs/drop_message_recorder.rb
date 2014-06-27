class Providers::Phone::Jobs::DropMessageRecorder
  include Sidekiq::Worker
  sidekiq_options :retry => false
  sidekiq_options :failures => true

  def perform(call_id, dropped_manually)
    call = Call.includes(:call_attempt => [:caller_session, :campaign, :voter]).find(call_id)
    call.update_recording!(dropped_manually)
  end
end
