desc "Populate Answer#caller_id from CallAttempt#caller_id using voter association"

task :populate_caller_id_for_answers => :environment do
	sql = "UPDATE answers JOIN voters ON answers.voter_id = voters.id JOIN call_attempts ON call_attempts.voter_id = voters.id SET answers.caller_id = call_attempts.caller_id"
	ActiveRecord::Base.connection.execute(sql)
end
