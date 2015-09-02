local active_key          = KEYS[1]
local inactive_key        = KEYS[3]
local hash_key            = ARGV[1]
local uuid_map            = cjson.decode(ARGV[2])
local _active_household   = redis.call('HGET', active_key, hash_key)
local _inactive_household = redis.call('HGET', inactive_key, hash_key)
local household           = {}

local update_leads = function (key, _house)
  if not _house then
    return 
  end
  local household     = cjson.decode(_house)
  local updated_leads = {}

  for _,lead in pairs(household.leads) do
    local uuid     = lead.uuid
    local sql_id   = uuid_map[uuid]
    if sql_id ~= nil then
      lead['sql_id'] = sql_id
    end
    table.insert(updated_leads, lead)
  end

  household.leads = updated_leads
  redis.call('HSET', key, hash_key, cjson.encode(household))
end

if _active_household == nil and _inactive_household == nil then
  -- no active or inactive household by that phone
  return -1
end

update_leads(active_key, _active_household)
update_leads(inactive_key, _inactive_household)

