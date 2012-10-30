desc 'Stop syncing with master'

task :redis_stop_slave => :environment do
  [$redis_call_flow_connection,
   $redis_call_end_connection,
   $redis_dialer_connection,
   $redis_on_hold_connection,
   $redis_question_pr_uri_connection,
   $redis_phones_ans_uri_connection,
   $redis_caller_session_uri_connection,
   $redis_call_uri_connection,
   Resque.redis].each do |conn|
    conn.slaveof('NO', 'ONE')
  end

  Sidekiq::RedisConnection.create.with{|c| c.slaveof('no', 'one')}

end