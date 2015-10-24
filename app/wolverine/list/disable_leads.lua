local campaign_stats_key     = KEYS[3]
local available_set_key      = KEYS[4]
local recycle_bin_set_key    = KEYS[5]
local blocked_set_key        = KEYS[6]
local completed_set_key      = KEYS[7]
local completed_lead_key     = KEYS[8]
local presented_set_key      = KEYS[11]
local base_key               = ARGV[1]
local list_id                = tonumber(ARGV[2])
local households             = cjson.decode(ARGV[3])
local count                  = 0

local merge_leads = function (lead, lead_id_set)
  lead_id_set[lead.custom_id] = lead
end

local copy_household_primitives = function(source_hh, dest_hh)
  for k,v in pairs(source_hh) do
    if k ~= 'leads' and v ~= nil and v ~= "" then
      dest_hh[k] = v
    end
  end
end

local zscorerem = function(set_key, entry)
  local score = redis.call('ZSCORE', set_key, entry)
  if score then
    redis.call('ZREM', set_key, entry)
  end
  return score
end

local lead_is_not_completed = function(lead)
  local bit = redis.call('GETBIT', completed_lead_key, lead.sequence)
  return bit == 0
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
  local available_lead_count   = 0

  if _inactive_household then
    -- destination household exists, prepare to merge/append leads
    inactive_household     = cjson.decode(_inactive_household)
    current_inactive_leads = inactive_household.leads
  end

  if _active_household then
    active_household = cjson.decode(_active_household)
  end

  if active_household and active_household.leads ~= nil and next(active_household.leads) ~= nil then
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
          lead_id_set[lead.custom_id] = lead
        end
        count = count + 1
        redis.call('HINCRBY', campaign_stats_key, 'total_leads', -1)
        table.insert(new_inactive_leads, lead)
      else
        if lead_is_not_completed(lead) then
          available_lead_count = available_lead_count + 1
        end
        -- lead does not belong to target list, so leave in active
        table.insert(new_active_leads, lead)
      end
    end

    local score = nil
    if #new_active_leads ~= 0 then
      active_household.leads = new_active_leads
      redis.call('HSET', active_key, hkey, cjson.encode(active_household))

      if available_lead_count == 0 then
        score = zscorerem(available_set_key, phone)
        if not score then
          score = zscorerem(recycle_bin_set_key, phone)
        end
        if not score then
          score = zscorerem(presented_set_key, phone)
        end
        if score then
          redis.call('ZADD', completed_set_key, score, phone)
        end
      end
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
        else
          score = redis.call('ZSCORE', completed_set_key, phone)
          if score then
            redis.call('ZREM', completed_set_key, phone)
          end
        end
      end

      redis.call('ZREM', blocked_set_key, phone)
      redis.call('HINCRBY', campaign_stats_key, 'total_numbers', -1)
      redis.call('HDEL', active_key, hkey)
    end
    if #new_inactive_leads ~= 0 then
      if #inactive_household == 0 then
        copy_household_primitives(active_household, inactive_household)
      end
      inactive_household.leads = new_inactive_leads
      if score then
        inactive_household.score = score
      end
      redis.call('HSET', inactive_key, hkey, cjson.encode(inactive_household))
    end
  end
end


return count 

