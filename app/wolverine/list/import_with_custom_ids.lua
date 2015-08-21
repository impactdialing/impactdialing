-- key order from ruby land
-- voter_list.imports_stats_key,
-- voter_list.campaign.imports_stats_key,
-- dial_queue.available.keys[:active],
-- dial_queue.recycle_bin.keys[:bin],
-- dial_queue.blocked.keys[:blocked],
-- dial_queue.completed.keys[:completed]

local pending_set_key             = KEYS[1]
local list_stats_key              = KEYS[2]
local campaign_stats_key          = KEYS[3]
local available_set_key           = KEYS[4]
local recycle_bin_set_key         = KEYS[5]
local blocked_set_key             = KEYS[6]
local completed_set_key           = KEYS[7]
local custom_id_register_key_base = KEYS[8]
local household_key_base          = ARGV[1] -- dial_queue:{campaign_id}:households:active
local starting_household_sequence = ARGV[2]
local households                  = cjson.decode(ARGV[3])
local update_statistics           = 1
local _updated_hh                 = {}
local new_number_count            = 0
local pre_existing_number_count   = 0
local new_lead_count              = 0
local updated_lead_count          = 0

local log = function (message)
  redis.call('RPUSH', 'debug.log', message)
end
local capture = function (k,data)
  redis.call('RPUSH', 'debug.' .. k, cjson.encode(data))
end

-- build household key parts
local household_key_parts = function(phone)
  local rkey = household_key_base .. ':' .. string.sub(phone, 0, -4)
  local hkey = string.sub(phone, -3, -1)
  return {rkey, hkey}
end

-- build custom id key parts
local custom_id_register_key_parts = function(custom_id)
  local hkey   = nil
  local rkey   = custom_id_register_key_base
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

local add_to_set = function(leads_added, blocked, score, phone)
  if tonumber(blocked) == 0 or blocked == nil then
    local completed_score = redis.call('ZSCORE', completed_set_key, phone)

    if leads_added or (not completed_score) then
      -- leads were added or the household is not complete
      local recycled_score = redis.call('ZSCORE', recycle_bin_set_key, phone)

      if (not recycled_score) then
        if leads_added and completed_score then
          -- household is no longer considered complete if leads were added
          -- preserve score from completed set to prevent recycle rate violations
          redis.call('ZADD', pending_set_key, completed_score, phone)
          redis.call('ZREM', completed_set_key, phone)
          --redis.call('LPUSH', 'debug', 'leads_added: ' .. tostring(leads_added) .. '; completed score: ' .. tostring(completed_score))
        else
          redis.call('ZADD', pending_set_key, score, phone)
        end
      end
    end
  else
    -- add to blocked set
    redis.call('ZADD', blocked_set_key, blocked, phone)
    redis.call('ZREM', available_set_key, phone)
    redis.call('ZREM', recycle_bin_set_key, phone)
  end
end

local remove_lead_from_current_household = function(custom_id, phone)
  -- current_registration is zscore where left of decimal is phone and right of decimal is 0
  local key_parts     = household_key_parts(phone)
  local household_key = key_parts[1]
  local phone_key     = key_parts[2]
  local _household    = redis.call('HGET', household_key, phone_key)
  local seq           = nil

  if _household then
    local household    = cjson.decode(_household)
    local new_leads    = {}
    new_lead_count     = new_lead_count - 1
    updated_lead_count = updated_lead_count + 1

    for _,lead in pairs(household.leads) do
      if tostring(lead.custom_id) ~= custom_id then
        table.insert(new_leads, lead)
      else
        seq = lead.sequence
      end
    end
    if #new_leads > 0 then
      household.leads = new_leads
      redis.call('HSET', household_key, phone_key, cjson.encode(household))
    else
      redis.call('HDEL', household_key, phone_key)
    end
  end

  return seq
end

local register_custom_id = function(custom_id, phone)
  local register_keys = custom_id_register_key_parts(custom_id)
  local current_phone = redis.call('HGET', register_keys[1], register_keys[2])
  local seq           = nil

  if current_phone and current_phone ~= phone then
    -- custom id already registered & possibly stored in household hash
    seq = remove_lead_from_current_household(custom_id, current_phone)
  end

  redis.call('HSET', register_keys[1], register_keys[2], phone)
  return seq
end

local build_custom_id_set = function (leads)
  local lead_id_set       = {}
  local seq = nil

  if leads[1] and leads[1].custom_id ~= nil then
    -- handle updates, merge leads
    for _,lead in pairs(leads) do
      local custom_id = tostring(lead.custom_id)
      if custom_id ~= "nil" then
        seq = register_custom_id(custom_id, lead.phone)
        if seq ~= nil then
          lead['sequence'] = seq
        end
        if lead_id_set[custom_id] ~= nil then
          lead['sequence'] = lead_id_set[custom_id]['sequence']
        end
        lead_id_set[custom_id] = lead
      end
    end
  end

  return lead_id_set
end

local update_lead = function (lead_to_update, lead_with_updates)
  for k,v in pairs(lead_with_updates) do
    if k ~= 'uuid' and k ~= 'custom_id' then
      lead_to_update[k] = lead_with_updates[k]
    end
  end
end

local create_lead_sequence = function (lead)
  log('creating new sequence for: '..cjson.encode(lead))
  if lead['sequence'] == nil then
    lead['sequence'] = redis.call('HINCRBY', campaign_stats_key, 'lead_sequence', 1)
  end
  log('lead got sequence: '..lead['sequence'])
end

local merge_leads = function(current_leads, new_leads)
  local merged_leads  = {}

  for custom_id,new_lead in pairs(new_leads) do
    local current_lead = current_leads[custom_id]
    if current_lead then
      update_lead(current_lead, new_lead)
      merged_leads[custom_id] = current_lead
      updated_lead_count = updated_lead_count + 1
    else
      if merged_leads[custom_id] == nil then
        new_lead_count = new_lead_count + 1
        create_lead_sequence(new_lead)
      end
      merged_leads[custom_id] = new_lead
    end
  end
  -- convert to basic array instead of dict to avoid encoding as json object instead of array
  local _merged_leads = {}
  for _,lead in pairs(merged_leads) do
    table.insert(_merged_leads, lead)
  end

  return _merged_leads
end

local next = next

for phone,household in pairs(households) do
  log('processing phone: '..phone)
  local key_parts       = household_key_parts(phone)
  local household_key   = key_parts[1]
  local phone_key       = key_parts[2]
  local new_leads       = household['leads']
  local uuid            = household['uuid']
  local sequence        = nil
  local updated_leads   = {}
  local current_hh      = {}
  local updated_hh      = household
  local score           = new_leads[1].line_number
  local leads_added     = false
  local _current_hh     = redis.call('HGET', household_key, phone_key)
  local new_lead_id_set = build_custom_id_set(new_leads)

  if next(new_lead_id_set) ~= nil then
    new_leads = new_lead_id_set
  end

  if _current_hh then
    log('current hh, updating stuff')
    -- this household has been saved so merge
    -- current_hh = cmsgpack.unpack(_current_hh)
    current_hh = cjson.decode(_current_hh)

    -- hh attributes
    uuid     = current_hh['uuid']
    sequence = current_hh['sequence']
    score    = current_hh['score']

    -- leads
    local current_leads       = current_hh['leads']
    local current_lead_id_set = build_custom_id_set(current_leads)
    
    -- if existing & new don't have custom ids then go to append mode
    -- campaign contract says each list will either use or not custom ids as of July 2015
    if next(current_lead_id_set) ~= nil and next(new_lead_id_set) ~= nil then
      log('using custom ids, both id sets have members')
      log('current set: '..cjson.encode(current_lead_id_set))
      log('new set: '..cjson.encode(new_lead_id_set))
      updated_leads = merge_leads(current_lead_id_set, new_lead_id_set)

      if new_lead_count > 0 then
        leads_added = true
      end
    end

    if tonumber(sequence) <= tonumber(starting_household_sequence) then
      pre_existing_number_count = pre_existing_number_count + 1
    end
  else
    log('no current hh, adding new stuff')
    -- brand new household
    for _,lead in pairs(new_leads) do
      new_lead_count = new_lead_count + 1
      create_lead_sequence(lead)
      table.insert(updated_leads, lead)
    end
    new_number_count = new_number_count + 1

    sequence = redis.call('HINCRBY', campaign_stats_key, 'number_sequence', 1)
  end

  updated_hh['leads']    = updated_leads
  updated_hh['uuid']     = uuid
  updated_hh['sequence'] = sequence

  add_to_set(leads_added, updated_hh['blocked'], score, phone)

  local _updated_hh = cjson.encode(updated_hh)
  log('HSET '..household_key..' => '..phone_key..' = '.._updated_hh)
  redis.call('HSET', household_key, phone_key, _updated_hh)
end

-- these stats will be used by the new voter list display so do not expire

redis.call('HINCRBY', list_stats_key, 'new_leads', new_lead_count)
redis.call('HINCRBY', list_stats_key, 'updated_leads', updated_lead_count)
redis.call('HINCRBY', list_stats_key, 'new_numbers', new_number_count)
redis.call('HINCRBY', list_stats_key, 'pre_existing_numbers', pre_existing_number_count)
redis.call('HINCRBY', list_stats_key, 'total_leads', new_lead_count)
redis.call('HINCRBY', list_stats_key, 'total_numbers', new_number_count)
redis.call('HINCRBY', campaign_stats_key, 'total_leads', new_lead_count)
redis.call('HINCRBY', campaign_stats_key, 'total_numbers', new_number_count)

