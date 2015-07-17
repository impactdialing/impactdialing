-- key order from ruby land
-- voter_list.imports_stats_key,
-- voter_list.campaign.imports_stats_key,
-- dial_queue.available.keys[:active],
-- dial_queue.recycle_bin.keys[:bin],
-- dial_queue.blocked.keys[:blocked],
-- dial_queue.completed.keys[:completed]

local pending_set_key           = KEYS[1]
local list_stats_key            = KEYS[2]
local campaign_stats_key        = KEYS[3]
local available_set_key         = KEYS[4]
local recycle_bin_set_key       = KEYS[5]
local blocked_set_key           = KEYS[6]
local completed_set_key         = KEYS[7]
local custom_id_set_key         = KEYS[8]
local household_key_base        = ARGV[1] -- dial_queue:{campaign_id}:households:active
local households                = cjson.decode(ARGV[2])
local update_statistics         = 1
local _updated_hh               = {}
local new_number_count          = 0
local pre_existing_number_count = 0
local new_lead_count            = 0
local updated_lead_count        = 0

local log = function (message)
  redis.call('RPUSH', 'debug.log', message)
end
local capture = function (k,data)
  redis.call('RPUSH', 'debug.' .. k, cjson.encode(data))
end

-- build household key parts
local household_key_parts = function(phone)
  local household_key   = household_key_base .. ':' .. string.sub(phone, 0, -4)
  local phone_key       = string.sub(phone, -3, -1)
  return {household_key, phone_key}
end

-- calculates score for new members
-- existing scores must be preserved w/ aggregate max on unionstore
local zscore = function (sequence)
  local d = 1000000
  local y = sequence / d
  return 1 + y
end

local add_to_set = function(leads_added, blocked, sequence, phone)
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
          redis.call('ZADD', pending_set_key, zscore(sequence), phone)
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
  if _household then
    local household    = cjson.decode(_household)
    local new_leads    = {}
    new_lead_count     = new_lead_count - 1
    updated_lead_count = updated_lead_count + 1

    for _,lead in pairs(household.leads) do
      if tostring(lead.custom_id) ~= custom_id then
        table.insert(new_leads, lead)
      end
    end
    if #new_leads > 0 then
      household.leads = new_leads
      redis.call('HSET', household_key, phone_key, cjson.encode(household))
    else
      redis.call('HDEL', household_key, phone_key)
    end
  end
end

local register_custom_id = function(custom_id, phone)
  local current_registration = redis.call('ZSCORE', custom_id_set_key, custom_id)

  if current_registration then
    local current_phone = tostring(math.modf(current_registration))
    if current_phone ~= phone then
      log('current_registration: '..current_phone..' for: '..custom_id..' and '..phone)
      -- custom id already registered & possibly stored in household hash
      remove_lead_from_current_household(custom_id, current_phone)

    end
  end
  redis.call('ZADD', custom_id_set_key, phone, custom_id)
end

local build_custom_id_set = function(leads)
  local lead_id_set       = {}

  if leads[1] and leads[1].custom_id ~= nil then
    -- handle updates, merge leads
    for _,lead in pairs(leads) do
      local custom_id = tostring(lead.custom_id)
      if custom_id ~= "nil" then
        lead_id_set[custom_id] = lead
        register_custom_id(custom_id, lead.phone)
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

local merge_leads = function(current_leads, new_leads)
  local merged_leads  = {}
  local results       = {}
  local updated_leads = 0
  local added_leads   = 0

  for custom_id,new_lead in pairs(new_leads) do
    local current_lead = current_leads[custom_id]
    if current_lead then
      merged_leads[custom_id] = update_lead(current_lead, new_lead)
      updated_lead_count = updated_lead_count + 1
    else
      if merged_leads[custom_id] == nil then
        new_lead_count = new_lead_count + 1
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
  local leads_added     = false
  local _current_hh     = redis.call('HGET', household_key, phone_key)
  local new_lead_id_set = build_custom_id_set(new_leads)

  if next(new_lead_id_set) ~= nil then
    new_leads = new_lead_id_set
  end

  if _current_hh then
    -- this household has been saved so merge
    -- current_hh = cmsgpack.unpack(_current_hh)
    current_hh = cjson.decode(_current_hh)

    -- hh attributes
    uuid     = current_hh['uuid']
    sequence = current_hh['sequence']

    -- leads
    local current_leads       = current_hh['leads']
    local current_lead_id_set = build_custom_id_set(current_leads)
    
    -- if existing & new don't have custom ids then go to append mode
    if next(current_lead_id_set) ~= nil and next(new_lead_id_set) ~= nil then
      updated_leads = merge_leads(current_lead_id_set, new_lead_id_set)

      if new_lead_count > 0 then
        leads_added = true
      end
    else
      -- not using custom ids, append all leads
      updated_leads = current_leads

      for _,lead in pairs(new_leads) do
        new_lead_count = new_lead_count + 1
        table.insert(updated_leads, lead)
      end

      leads_added = true
    end

    pre_existing_number_count = pre_existing_number_count + 1
  else
    -- brand new household
    for _,lead in pairs(new_leads) do
      new_lead_count = new_lead_count + 1
      table.insert(updated_leads, lead)
    end
    new_number_count = new_number_count + 1

    sequence = redis.call('HINCRBY', campaign_stats_key, 'number_sequence', 1)
  end

  updated_hh['leads']    = updated_leads
  updated_hh['uuid']     = uuid
  updated_hh['sequence'] = sequence

  add_to_set(leads_added, updated_hh['blocked'], updated_hh['sequence'], phone)

  local _updated_hh = cjson.encode(updated_hh)
  redis.call('HSET', household_key, phone_key, _updated_hh)
end

-- these stats will be used by the new voter list display so do not expire
local total_lead_count   = new_lead_count + updated_lead_count
local total_number_count = new_number_count + pre_existing_number_count

redis.call('HINCRBY', list_stats_key, 'new_leads', new_lead_count)
redis.call('HINCRBY', list_stats_key, 'updated_leads', updated_lead_count)
redis.call('HINCRBY', list_stats_key, 'new_numbers', new_number_count)
redis.call('HINCRBY', list_stats_key, 'pre_existing_numbers', pre_existing_number_count)
redis.call('HINCRBY', list_stats_key, 'total_leads', total_lead_count)
redis.call('HINCRBY', list_stats_key, 'total_numbers', total_number_count)
redis.call('HINCRBY', campaign_stats_key, 'total_leads', new_lead_count)
redis.call('HINCRBY', campaign_stats_key, 'total_numbers', new_number_count)

