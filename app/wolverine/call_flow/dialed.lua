local call_data     = cjson.decode(ARGV[1])
local other_data    = cjson.decode(ARGV[2])
local data          = {}
local next          = next
local populate_data = function(source)
  if next(source) == nil then
    return
  end

  for property,value in pairs(source) do
    redis.call('HSET', KEYS[2], property, value)
  end
end

populate_data(call_data)
populate_data(other_data)

-- predictive dial mode only
if tonumber(ARGV[3]) > 0 then
  redis.call('HINCRBY', KEYS[1], 'presented', -1)
end
redis.call('HINCRBY', KEYS[1], 'ringing', 1)

