local redis_key          = KEYS[1]
local register_key       = KEYS[2]
local list_stats_key     = KEYS[9]
local campaign_stats_key = KEYS[10]
local hash_key           = ARGV[1]
local target_id          = ARGV[2]
local register_hkey      = ARGV[3]
local _house             = redis.call('HGET', redis_key, hash_key)
local house              = {}
local remaining_leads    = {}
local deleted_houses     = {}
local output             = {}
local removed_count      = 0
local next               = next

if _house then
  house = cjson.decode(_house)
  
  if house and house.leads ~= nil and next(house.leads) ~= nil then
    for _,lead in pairs(house.leads) do
      if lead.custom_id ~= target_id then
        table.insert(remaining_leads, lead)
      else
        removed_count = removed_count + 1
      end
    end

    if next(remaining_leads) ~= nil then
      house.leads = remaining_leads
      _house      = cjson.encode(house)
      redis.call('HSET', redis_key, hash_key, _house)
      redis.call('HDEL', register_key, register_hkey)
    else
      table.insert(deleted_houses, house.phone)
      redis.call('HDEL', redis_key, hash_key)
      redis.call('HDEL', register_key, register_hkey)
    end

    redis.call('HINCRBY', campaign_stats_key, 'total_leads', -(removed_count))
    redis.call('HINCRBY', list_stats_key, 'removed_leads', 1)
  end
end

redis.call('HINCRBY', list_stats_key, 'total_leads', 1)

table.insert(output, removed_count)
table.insert(output, deleted_houses)

return cjson.encode(output)
