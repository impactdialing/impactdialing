local call_data     = cjson.decode(ARGV[1])
local other_data    = cjson.decode(ARGV[2])
local data          = {}
local populate_data = function(source)
  if next(source) == nil then
    return
  end

  for property,value in pairs(source) do
    --table.insert(data, property)
    --table.insert(data, value)
    redis.call('HSET', KEYS[2], property, value)
  end
end

populate_data(call_data)
populate_data(other_data)

-- predictive dial mode only
if tonumber(ARGV[3]) > 0 then
  redis.call('HINCRBY', KEYS[1], 'presented', -1)
end
-- debugging
--redis.call('RPUSH', 'debug.log', 'calling HMSET with: '..unpack(data))
redis.call('HINCRBY', KEYS[1], 'ringing', 1)
--redis.call('HMSET', KEYS[2], unpack(data))

