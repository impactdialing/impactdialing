local presented_key      = KEYS[1]
local recycle_bin_key    = KEYS[2]
local completed_key      = KEYS[3]
local phone              = ARGV[1]
local add_to_recycle_bin = ARGV[2]
local zscore             = redis.call('ZSCORE', presented_key, phone)

if tonumber(add_to_recycle_bin) > 0 then
  redis.call('ZADD', recycle_bin_key, zscore, phone)
else
  redis.call('ZADD', completed_key, zscore, phone)
end

redis.call('ZREM', presented_key, phone)

