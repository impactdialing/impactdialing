require Rails.root.join("lib/cleanup_in_progress_call_attempts.rb")

desc "Daily cleanup of unwrapped calls and ringing ,lines"

task :clean_up => :environment do
  CleanupInProgressCallAttempts.cleanup!
end
