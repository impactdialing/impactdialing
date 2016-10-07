STDOUT.puts "Connecting to redis using #{ENV['REDIS_URL']}"
# open 8 connections per app instance
$redis_call_flow_connection          = Redis.new
$redis_call_end_connection           = Redis.new
$redis_dialer_connection             = Redis.new
$redis_on_hold_connection            = Redis.new
$redis_question_pr_uri_connection    = Redis.new
$redis_phones_ans_uri_connection     = Redis.new
$redis_caller_session_uri_connection = Redis.new
$redis_call_uri_connection           = Redis.new
