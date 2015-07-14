-- key order from ruby land
-- voter_list.imports_stats_key,
-- voter_list.campaign.imports_stats_key,
-- dial_queue.available.keys[:active],
-- dial_queue.recycle_bin.keys[:bin],
-- dial_queue.blocked.keys[:blocked],
-- dial_queue.completed.keys[:completed]

local pending_set_key           = KEYS[1]
local campaign_stats_key        = KEYS[3]
local available_set_key         = KEYS[4]
local recycle_bin_set_key       = KEYS[5]
local blocked_set_key           = KEYS[6]
local completed_set_key         = KEYS[7]
local household_key_base        = ARGV[1] -- dial_queue:{campaign_id}:households:active
local voter_list_id             = tonumber(ARGV[2])
local households                = cjson.decode(ARGV[3])
local update_statistics         = 1
local _updated_hh               = {}
local new_number_count          = 0
local pre_existing_number_count = 0
local new_lead_count            = 0
local updated_lead_count        = 0

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

local merge_leads = function (lead, lead_id_set)
  local merged = false
  if lead_id_set[lead.custom_id] ~= nil and tonumber(lead_id_set[lead.custom_id].voter_list_id) == voter_list_id then
    merged = true

    for k,v in pairs(lead) do
      if k ~= 'uuid' and k ~= 'custom_id' then
        lead_id_set[lead.custom_id][k] = v
      end
    end
  else
    lead_id_set[lead.custom_id] = lead
  end

  return merged
end

for phone,household in pairs(households) do
  local household_key = household_key_base .. ':' .. string.sub(phone, 0, -4)
  local phone_key     = string.sub(phone, -3, -1)
  local new_leads     = household['leads']
  local uuid          = household['uuid']
  local sequence      = nil
  local updated_leads = {}
  local current_hh    = {}
  local updated_hh    = household
  local leads_added   = false
  local _current_hh   = redis.call('HGET', household_key, phone_key)

  if _current_hh then
    -- this household has been saved so merge
    -- current_hh = cmsgpack.unpack(_current_hh)
    current_hh = cjson.decode(_current_hh)

    -- hh attributes
    uuid     = current_hh['uuid']
    sequence = current_hh['sequence']

    -- leads
    local current_leads = current_hh['leads']
    
    if current_leads[1] and current_leads[1].custom_id ~= nil then
      -- handle updates, merge leads
      local lead_id_set   = {}
      for _,lead in pairs(current_leads) do
        lead_id_set[lead.custom_id] = lead
      end

      for _,lead in pairs(new_leads) do
        if merge_leads(lead, lead_id_set) then
          updated_lead_count = updated_lead_count + 1
        else
          leads_added    = true
          new_lead_count = new_lead_count + 1
        end

        table.insert(updated_leads, lead_id_set[lead.custom_id])
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
    -- note: when enabling a list, households get a new sequence
    -- note: the sequence is used solely for scoring zset members (phone numbers)
    -- note: which isn't great since enabling a list changes the order leads will be dialed
    -- note: but is acceptable for now because enable/disable is likely going away for good
    -- todo: remove these notes when enable/disable voter list feature is removed
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

  -- local _updated_hh = cmsgpack.pack(updated_hh)
  local _updated_hh = cjson.encode(updated_hh)

  redis.call('HSET', household_key, phone_key, _updated_hh)
end

-- these stats will be used by the new voter list display so do not expire
local total_lead_count   = new_lead_count + updated_lead_count
local total_number_count = new_number_count + pre_existing_number_count

redis.call('HINCRBY', campaign_stats_key, 'total_leads', new_lead_count)
redis.call('HINCRBY', campaign_stats_key, 'total_numbers', new_number_count)

