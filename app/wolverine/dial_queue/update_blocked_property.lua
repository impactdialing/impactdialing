local active_key     = KEYS[1]
local inactive_key   = KEYS[3]
local active_zset    = KEYS[4]
local presented_zset = KEYS[5]
local recycle_zset   = KEYS[6]
local blocked_zset   = KEYS[7]
local hash_key       = ARGV[1]
local blocked_int    = tonumber(ARGV[2])
local phone          = ARGV[3]
local blocked_score  = 0

local update_hh = function(key)
  local _hh = redis.call('HGET', key, hash_key)
  if not _hh then
    return
  end

  local hh = cjson.decode(_hh)
  blocked_score = hh.blocked + blocked_int
  hh.blocked    = blocked_score
  redis.call('HSET', key, hash_key, cjson.encode(hh))
end

local zset_rem = function(zset)
  redis.call('ZREM', zset, phone)
end
local zset_add = function(zset)
  redis.call('ZADD', zset, blocked_score, phone)
end

update_hh(active_key)
update_hh(inactive_key)

if blocked_score > 0 then
  zset_rem(active_zset)
  zset_rem(presented_zset)
  zset_rem(recycle_zset)
  zset_add(blocked_zset)
else
  zset_rem(blocked_zset)
  zset_add(recycle_zset)
end
