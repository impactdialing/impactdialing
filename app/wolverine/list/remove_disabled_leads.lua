local campaign_stats_key  = KEYS[3]
local available_set_key   = KEYS[4]
local recycle_bin_set_key = KEYS[5]
local blocked_set_key     = KEYS[6]
local completed_set_key   = KEYS[7]
local base_key            = ARGV[1]
local list_id             = tonumber(ARGV[2])
local households          = cjson.decode(ARGV[3])
local count               = 0
local _leads              = {}

for phone,hkey in pairs(households) do
  local key        = base_key .. ':' .. string.sub(phone, 0, -4)
  local hkey       = string.sub(phone, -3, -1)
  local _household = redis.call('HGET', key, hkey)
  if _household then
    local household    = cjson.decode(_household)
    local active_leads = {}
    local leads        = household.leads

    for _,lead in pairs(leads) do
      if tonumber(lead.voter_list_id) ~= list_id then
        table.insert(active_leads, lead)
      else
        count = count + 1
        redis.call('HINCRBY', campaign_stats_key, 'total_leads', -1)
      end
    end

    if #active_leads > 0 then
      household.leads = active_leads
      redis.call('HSET', key, hkey, cjson.encode(household))
    else
      -- household has no active leads from other lists
      redis.call('ZREM', available_set_key, phone)
      redis.call('ZREM', recycle_bin_set_key, phone)
      redis.call('ZREM', blocked_set_key, phone)
      redis.call('HINCRBY', campaign_stats_key, 'total_numbers', -1)
      redis.call('HDEL', key, hkey)
    end
  end
end

return count 

