local household              = cjson.decode(ARGV[1])
local new_household          = {}
local lead_enabled_bit       = ARGV[2]
local lead_id_map            = cjson.decode(ARGV[3])
local redis_key              = ARGV[4]
local hash_key               = ARGV[5]
local stats_key              = ARGV[6]
local dispositioned_lead_key = ARGV[7]
local completed_lead_key     = ARGV[8]
local message_drop_key       = ARGV[9]
local custom_id_register_key = ARGV[10]
local available_active_key   = ARGV[11]
local blocked_key            = ARGV[12]
local completed_key          = ARGV[13]
local failed_key             = ARGV[14]
local inactive_redis_key     = ARGV[15]
local old_leads              = household.leads
local new_leads              = {} -- new 'active' leads
local inactive_leads         = {}
local inactive_household     = {}

local custom_id_register_key_parts = function(custom_id)
  local hkey   = nil
  local rkey   = custom_id_register_key
  local id_len = string.len(custom_id)

  if id_len > 3 then
    local rkey_stop = id_len - 3
    rkey = rkey..':'..string.sub(custom_id, 0, rkey_stop)
    hkey = string.sub(custom_id, -3, -1)
  else
    hkey = custom_id
    -- rkey is base key for ids w/ < 3 characters
  end
  return {rkey, hkey}
end

local register_custom_id = function(custom_id, phone)
  local register_keys = custom_id_register_key_parts(custom_id)
  local current_phone = redis.call('HGET', register_keys[1], register_keys[2])

  redis.call('HSET', register_keys[1], register_keys[2], phone)
end

for property,value in pairs(household) do
  if property ~= 'message_dropped' and property ~= 'dialed' and property ~= 'completed' and property ~= 'failed' and property ~= 'leads' and property ~= 'has_leads_enabled' then
    new_household[property] = value
  end
end

for _,old_lead in pairs(old_leads) do
  local new_lead = old_lead
  local id_map   = lead_id_map[tostring(old_lead.sql_id)]

  new_lead.sequence = redis.call('HINCRBY', stats_key, 'lead_sequence', 1)

  -- register custom ids as needed
  if old_lead.custom_id ~= nil then
    register_custom_id(tostring(old_lead.custom_id), household.phone)
  end

  -- mark dispositioned as needed
  if tonumber(id_map.dispositioned) == 1 then
    redis.call('SETBIT', dispositioned_lead_key, new_lead.sequence, 1)

    -- mark completed as needed
    if tonumber(id_map.completed) == 1 then
      redis.call('SETBIT', completed_lead_key, new_lead.sequence, 1)
    end
  end

  redis.call('HINCRBY', stats_key, 'total_leads', 1)

  if tonumber(new_lead.enabled) == 1 then
    table.insert(new_leads, new_lead)
  else
    table.insert(inactive_leads, new_lead)
  end
end

new_household.sequence = redis.call('HINCRBY', stats_key, 'number_sequence', 1)
if #inactive_leads > 0 then
  for prop,val in pairs(new_household) do
    inactive_household[prop] = val
  end
  inactive_household.leads = inactive_leads
end
if #new_leads > 0 then
  new_household.leads    = new_leads
end

-- mark message dropped as needed
if tonumber(household.message_dropped) == 1 then
  redis.call('SETBIT', message_drop_key, new_household.sequence, 1)
end

-- update not dialed score as needed
if tonumber(household.dialed) == 0 then
  if #inactive_leads > 0 then
    inactive_household.score = new_household.sequence
  end
  if #new_leads > 0 then
    new_household.score = new_household.sequence
  end
end

if tonumber(household.blocked) ~= 0 and tonumber(household.has_leads_enabled) == 1 then
  redis.call('ZADD', blocked_key, household.blocked, household.phone)
elseif tonumber(household.dialed) == 0 and tonumber(household.failed) == 0 and tonumber(household.completed) == 0 then
  local available_score = redis.call('ZSCORE', available_active_key, household.phone)
  if #new_leads > 0 and available_score ~= nil then
    redis.call('ZADD', available_active_key, new_household.score, household.phone)
  end
elseif tonumber(household.completed) == 1 then
  redis.call('ZADD', completed_key, household.score, household.phone)
elseif tonumber(household.failed) == 1 then
  redis.call('ZADD', failed_key, household.score, household.phone)
end

if #new_leads > 0 then
  redis.call('HSET', redis_key, hash_key, cjson.encode(new_household))
end
if #inactive_leads > 0 then
  redis.call('HSET', inactive_redis_key, hash_key, cjson.encode(inactive_household))
end

redis.call('HINCRBY', stats_key, 'total_numbers', 1)

