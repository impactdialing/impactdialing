local phone = ARGV[1]
local score = redis.call('ZSCORE', KEYS[1], phone)
redis.call('ZREM', KEYS[1], phone)
redis.call('ZADD', KEYS[2], score, phone)

if tonumber(ARGV[2]) > 0 then
  redis.call('HINCRBY', KEYS[3], 'presented', -1)
end
