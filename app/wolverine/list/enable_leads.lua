local pending_set_key        = KEYS[1]
local campaign_stats_key     = KEYS[3]
local available_set_key      = KEYS[4]
local recycle_bin_set_key    = KEYS[5]
local blocked_set_key        = KEYS[6]
local completed_set_key      = KEYS[7]
local base_key               = ARGV[1]
local list_id                = tonumber(ARGV[2])
local households             = cjson.decode(ARGV[3])
local count                  = 0

local log = function (message)
  redis.call('RPUSH', 'debug.log', message)
end
local capture = function (k,data)
  redis.call('RPUSH', 'debug.' .. k, cjson.encode(data))
end

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
  local leads_added            = false
  local lead_id_set            = {}

  if _active_household then
    -- destination household exists, prepare for merge
    active_household     = cjson.decode(_active_household)

    log('parsed active household')
    capture('active_household', active_household)

    current_active_leads = active_household.leads
    if current_active_leads[1] and current_active_leads[1].custom_id ~= nil then
      -- current active leads have custom ids so make sure to merge & not duplicate
      for _,lead in pairs(current_active_leads) do
        lead_id_set[lead.custom_id] = lead
      end
    end
  end

  if _inactive_household then
    -- source household exists
    inactive_household     = cjson.decode(_inactive_household)

    log('parsed inactive household')
    capture('inactive_household', inactive_household)

    current_inactive_leads = inactive_household.leads

    for _,lead in pairs(current_inactive_leads) do
      if tonumber(lead.voter_list_id) == list_id then
        -- lead belongs to target list, so move to active
        log('lead.voter_list_id('..lead.voter_list_id..') == list_id('..list_id..')')
        if #lead_id_set ~= 0 then
          if merge_leads(lead, lead_id_set) == false then
            leads_added = true
          end
          lead = lead_id_set[lead.custom_id]
        end
        capture('new_active_leads', lead)
        count = count + 1
        redis.call('HINCRBY', campaign_stats_key, 'total_leads', 1)
        table.insert(new_active_leads, lead)
      else
        log('lead.voter_list_id('..lead.voter_list_id..') ~= list_id('..list_id..')')
        -- lead does not belong to target list, so leave in inactive
        capture('new_inactive_leads', lead)
        table.insert(new_inactive_leads, lead)
      end
    end

    log('#new_inactive_leads = '..#new_inactive_leads)
    log('#new_active_leads = '..#new_active_leads)
    if #new_inactive_leads ~= 0 then
      log('storing inactive leads')

      inactive_household.leads = new_inactive_leads
      redis.call('HSET', inactive_key, hkey, cjson.encode(inactive_household))
    else
      redis.call('HDEL', inactive_key, hkey)
    end
    if #new_active_leads ~= 0 then
      log('storing active leads')

      if #active_household == 0 then
        for k,v in pairs(inactive_household) do
          if k ~= 'leads' then
            active_household[k] = inactive_household[k]
          end
        end
      end
      active_household.leads = new_active_leads
      add_to_set(leads_added, active_household.blocked, inactive_household.score, phone)
      _active_household = cjson.encode(active_household)
      log('calling HSET with: '..active_key..', '..hkey..', '.._active_household)
      redis.call('HSET', active_key, hkey, _active_household)
      redis.call('HINCRBY', campaign_stats_key, 'total_numbers', 1)
    end
  end
end

return count 

