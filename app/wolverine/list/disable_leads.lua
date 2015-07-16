local campaign_stats_key     = KEYS[3]
local available_set_key      = KEYS[4]
local recycle_bin_set_key    = KEYS[5]
local blocked_set_key        = KEYS[6]
local completed_set_key      = KEYS[7]
local base_key               = ARGV[1]
local list_id                = tonumber(ARGV[2])
local households             = cjson.decode(ARGV[3])
local count                  = 0

local merge_leads = function (lead, lead_id_set)
  local merged = false
  if lead_id_set[lead.custom_id] ~= nil then
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

for phone,_ in pairs(households) do
  local phone_prefix           = string.sub(phone, 0, -4)
  local hkey                   = string.sub(phone, -3, -1)
  local active_key             = base_key .. ':active:' .. phone_prefix
  local inactive_key           = base_key .. ':inactive:' .. phone_prefix
  local _active_household      = redis.call('HGET', active_key, hkey)
  local active_household       = {}
  local _inactive_household    = redis.call('HGET', inactive_key, hkey)
  local inactive_household     = {}
  local new_inactive_leads     = {}
  local current_inactive_leads = {}
  local new_active_leads       = {}
  local current_active_leads   = {}

  if _inactive_household then
    -- destination household exists, prepare to merge/append leads
    inactive_household     = cjson.decode(_inactive_household)
    current_inactive_leads = inactive_household.leads
  end

  if _active_household then
    -- source household exists, begin moving leads
    active_household     = cjson.decode(_active_household)
    current_active_leads = active_household.leads
    local lead_id_set    = {}

    if current_inactive_leads[1] and current_inactive_leads[1].custom_id ~= nil then
      -- current inactive leads have custom ids so make sure to merge & not duplicate
      for _,lead in pairs(current_inactive_leads) do
        lead_id_set[lead.custom_id] = lead
      end
    else
      new_inactive_leads = current_inactive_leads
    end

    for _,lead in pairs(current_active_leads) do
      if tonumber(lead.voter_list_id) == list_id then
        -- lead belongs to target list, so move to inactive
        if #lead_id_set ~= 0 then
          merge_leads(lead, lead_id_set) 
          lead = lead_id_set[lead.custom_id]
        end
        count = count + 1
        redis.call('HINCRBY', campaign_stats_key, 'total_leads', -1)
        table.insert(new_inactive_leads, lead)
      else
        -- lead does not belong to target list, so leave in active
        table.insert(new_active_leads, lead)
      end
    end

    local score = nil
    if #new_active_leads ~= 0 then
      active_household.leads = new_active_leads
      redis.call('HSET', active_key, hkey, cjson.encode(active_household))
    else
      -- household has no active leads from other lists
      -- record the score to use when enabling
      score = redis.call('ZSCORE', available_set_key, phone)
      if score then
        redis.call('ZREM', available_set_key, phone)
      else
        score = redis.call('ZSCORE', recycle_bin_set_key, phone)
        if score then
          redis.call('ZREM', recycle_bin_set_key, phone)
        end
      end

      redis.call('ZREM', blocked_set_key, phone)
      redis.call('HINCRBY', campaign_stats_key, 'total_numbers', -1)
      redis.call('HDEL', active_key, hkey)
    end
    if #new_inactive_leads ~= 0 then
      inactive_household.leads = new_inactive_leads
      if score then
        inactive_household.score = score
      end
      redis.call('HSET', inactive_key, hkey, cjson.encode(inactive_household))
    end
  end
end

return count 

