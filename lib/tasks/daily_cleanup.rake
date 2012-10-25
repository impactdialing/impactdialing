desc "Daily cleanup of unwrapped calls and ringing ,lines"

task :clean_up => :environment do
  CallAttempt.update_all("status = 'not called' ", "status in ('Ringing', 'Call in progress', 'Call ready to dial') ")
  Voter.update_all( "status = 'not called'", "status in ('Ringing', 'Call in progress', 'Call ready to dial')")
end
