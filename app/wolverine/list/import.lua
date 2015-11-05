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
local completed_leads_key         = KEYS[8]
local message_drop_key            = KEYS[9]
local household_key_base          = ARGV[1] -- dial_queue:{campaign_id}:households:active
local starting_household_sequence = ARGV[2]
local message_drop_completes      = tonumber(ARGV[3])
local households                  = cjson.decode(ARGV[4])
local update_statistics           = 1
local _updated_hh                 = {}
local new_number_count            = 0
local pre_existing_number_count   = 0
local new_lead_count              = 0

-- build household key parts
local household_key_parts = function(phone)
  local rkey = household_key_base .. ':' .. string.sub(phone, 0, -4)
  local hkey = string.sub(phone, -3, -1)
  return {rkey, hkey}
end

-- enable/disable support
-- in case uploaded hh was recently dialed & disabled
local inactive_hh_count = 0
local i_household_key_parts = function(phone)
  local base = string.gsub(household_key_base, 'active', 'inactive')
  local rkey = base .. ':' .. string.sub(phone, 0, -4)
  local hkey = string.sub(phone, -3, -1)
  return {rkey, hkey}
end

local add_to_set = function(leads_added, blocked, score, sequence, phone, inactive_hh)
  if tonumber(blocked) == 0 or blocked == nil then
    local completed_score = redis.call('ZSCORE', completed_set_key, phone)

    if message_drop_completes > 0 then
      local message_dropped_bit = redis.call('GETBIT', message_drop_key, sequence)
      if tonumber(message_dropped_bit) > 0 then
        if not completed_score then
          redis.call('ZADD', completed_set_key, score, phone)
          completed_score = score
        end
        leads_added = false
      end
    end

    if leads_added or (not completed_score) then
      -- leads were added or the household is not complete
      local recycled_score = redis.call('ZSCORE', recycle_bin_set_key, phone)

      if (not recycled_score) then
        if leads_added and completed_score then
          -- household is no longer considered complete if leads were added
          -- preserve score from completed set to prevent recycle rate violations
          redis.call('ZADD', recycle_bin_set_key, completed_score, phone)
          redis.call('ZREM', completed_set_key, phone)
          --redis.call('LPUSH', 'debug', 'leads_added: ' .. tostring(leads_added) .. '; completed score: ' .. tostring(completed_score))
        else
          if inactive_hh then
            redis.call('ZADD', recycle_bin_set_key, score, phone)
          else
            redis.call('ZADD', pending_set_key, score, phone)
          end
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
  local inactive_hh     = false

  -- enable/disable support
  -- if uploaded hh is inactive
  -- then copy hh attrs from there
  if not _current_hh then
    local i_key_parts     = i_household_key_parts(phone)
    local i_household_key = i_key_parts[1]
    local i_phone_key     = i_key_parts[2]
    local _i_current_hh   = redis.call('HGET', i_household_key, i_phone_key)
    if _i_current_hh then
      local i_current_hh = cjson.decode(_i_current_hh)
      local i_hh         = {}
      i_hh.uuid          = i_current_hh.uuid
      i_hh.sequence      = i_current_hh.sequence
      i_hh.score         = i_current_hh.score
      i_hh.leads         = {} -- don't copy inactive leads
      current_hh         = i_hh
      inactive_hh        = true
      inactive_hh_count = inactive_hh_count + 1
    end
  end

  if _current_hh or current_hh.uuid then
    -- this household has been saved so merge
    -- current_hh = cmsgpack.unpack(_current_hh)
    if _current_hh then
      current_hh = cjson.decode(_current_hh)
    end
    -- hh attributes
    uuid          = current_hh.uuid
    sequence      = current_hh.sequence
    score         = current_hh.score
    updated_leads = current_hh.leads
    
    process_leads(updated_leads, new_leads)

    leads_added = true

    if tonumber(sequence) <= tonumber(starting_household_sequence) then
      pre_existing_number_count = pre_existing_number_count + 1
    end
  else
    -- brand new household
    process_leads(updated_leads, new_leads)

    new_number_count = new_number_count + 1
    sequence         = redis.call('HINCRBY', campaign_stats_key, 'number_sequence', 1)
    score            = sequence
  end

  updated_hh['leads']    = updated_leads
  updated_hh['uuid']     = uuid
  updated_hh['sequence'] = sequence
  updated_hh['score']    = score

  add_to_set(leads_added, updated_hh['blocked'], score, sequence, phone, inactive_hh)

  local _updated_hh = cjson.encode(updated_hh)
  redis.call('HSET', household_key, phone_key, _updated_hh)
end

-- these stats will be used by the new voter list display so do not expire

redis.call('HINCRBY', list_stats_key, 'new_leads', new_lead_count)
redis.call('HINCRBY', list_stats_key, 'new_numbers', new_number_count)
redis.call('HINCRBY', list_stats_key, 'pre_existing_numbers', pre_existing_number_count)
redis.call('HINCRBY', list_stats_key, 'total_leads', new_lead_count)
redis.call('HINCRBY', list_stats_key, 'total_numbers', new_number_count + pre_existing_number_count)
redis.call('HINCRBY', campaign_stats_key, 'total_leads', new_lead_count)
redis.call('HINCRBY', campaign_stats_key, 'total_numbers', new_number_count + inactive_hh_count)

