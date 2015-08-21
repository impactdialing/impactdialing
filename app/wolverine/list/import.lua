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
local household_key_base          = ARGV[1] -- dial_queue:{campaign_id}:households:active
local starting_household_sequence = ARGV[2]
local households                  = cjson.decode(ARGV[3])
local update_statistics           = 1
local _updated_hh                 = {}
local new_number_count            = 0
local pre_existing_number_count   = 0
local new_lead_count              = 0
local updated_lead_count          = 0

-- build household key parts
local household_key_parts = function(phone)
  local rkey = household_key_base .. ':' .. string.sub(phone, 0, -4)
  local hkey = string.sub(phone, -3, -1)
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

local create_lead_sequence = function (lead)
  if lead['sequence'] == nil then
    lead['sequence'] = redis.call('HINCRBY', campaign_stats_key, 'lead_sequence', 1)
  end
end

local process_leads = function (output, input)
  for _,lead in pairs(input) do
    new_lead_count = new_lead_count + 1
    create_lead_sequence(lead)
    table.insert(output, lead)
  end
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
  local score           = household['score']
  local leads_added     = false
  local _current_hh     = redis.call('HGET', household_key, phone_key)

  if _current_hh then
    log('current hh, updating stuff')
    -- this household has been saved so merge
    -- current_hh = cmsgpack.unpack(_current_hh)
    current_hh = cjson.decode(_current_hh)

    -- hh attributes
    uuid          = current_hh['uuid']
    sequence      = current_hh['sequence']
    score         = current_hh['score']
    updated_leads = current_hh['leads']
    
    process_leads(updated_leads, new_leads)

    leads_added = true

    if tonumber(sequence) <= tonumber(starting_household_sequence) then
      pre_existing_number_count = pre_existing_number_count + 1
    end
  else
    -- brand new household
    process_leads(updated_leads, new_leads)

    new_number_count = new_number_count + 1

    sequence = redis.call('HINCRBY', campaign_stats_key, 'number_sequence', 1)
  end

  updated_hh['leads']    = updated_leads
  updated_hh['uuid']     = uuid
  updated_hh['sequence'] = sequence

  add_to_set(leads_added, updated_hh['blocked'], score, phone)

  local _updated_hh = cjson.encode(updated_hh)
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

