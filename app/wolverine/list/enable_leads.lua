local pending_set_key        = KEYS[1]
local campaign_stats_key     = KEYS[3]
local available_set_key      = KEYS[4]
local recycle_bin_set_key    = KEYS[5]
local blocked_set_key        = KEYS[6]
local completed_set_key      = KEYS[7]
local completed_leads_key    = KEYS[8]
local message_drop_key       = KEYS[9]
local base_key               = ARGV[1]
local list_id                = tonumber(ARGV[2])
local message_drop_completes = tonumber(ARGV[3])
local households             = cjson.decode(ARGV[4])
local count                  = 0

local log = function (message)
  redis.call('RPUSH', 'debug.log', message)
end
local capture = function (k,data)
  redis.call('RPUSH', 'debug.' .. k, cjson.encode(data))
end

log('START enable_leads.lua')

local copy_household_primitives = function(source_hh, dest_hh)
  for k,v in pairs(source_hh) do
    if k ~= 'leads' and v ~= nil and v ~= "" then
      log('updating active household '..k..' with '..v)
      dest_hh[k] = v
    end
  end
end

local add_to_set = function(leads_added, household, phone)
  local score = household.score
  log('add_to_set: START: '..tostring(leads_added)..', '..tostring(household.blocked)..', '..tostring(score)..', '..tostring(phone))
  if tonumber(household.blocked) == 0 or household.blocked == nil then
    log('add_to_set: not blocked '..phone)

    local completed_score = redis.call('ZSCORE', completed_set_key, phone)
    if message_drop_completes > 0 then
      local message_dropped_bit = redis.call('GETBIT', message_drop_key, household.sequence)
      if tonumber(message_dropped_bit) > 0 then
        if not completed_score then
          redis.call('ZADD', completed_set_key, score, phone)
        end
        leads_added = false
      end
    end

    local available_score = redis.call('ZSCORE', available_set_key, phone)
    local recycled_score = redis.call('ZSCORE', recycle_bin_set_key, phone)

    if leads_added then
      log('add_to_set: leads added '..phone)
      -- leads were added 

      if (not available_score) then
        log('add_to_set: not in available '..phone)
        if completed_score then
          score = completed_score
          -- household is no longer considered complete if leads were added
          -- preserve score from completed set to prevent recycle rate violations
          redis.call('ZREM', completed_set_key, phone)
        elseif recycled_score then
          score = recycled_score
        end
        -- update recycle bin score or add phone to recycle bin
        redis.call('ZADD', recycle_bin_set_key, score, phone)
      end
    else
      log('add_to_set: no leads added, noop')
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

    current_inactive_leads = inactive_household.leads

    for _,lead in pairs(current_inactive_leads) do
      local lead_completed = redis.call('GETBIT', completed_leads_key, lead.sequence)
      if tonumber(lead.voter_list_id) == list_id then
        -- lead belongs to target list, so move to active
        log('lead.voter_list_id('..lead.voter_list_id..') == list_id('..list_id..')')
        if #lead_id_set ~= 0 then
          if lead_id_set[lead.custom_id] == nil then
            lead_id_set[lead.custom_id] = lead
            if lead_completed < 1 then
              leads_added = true
            end
            -- ignore inactive leads w/ matching custom id of active lead: active lead data wins
            -- and if all is well, then there should not be matching custom id between active/inactive
          end
        elseif lead_completed < 1 then
          leads_added = true
        end
        log('new active leads '..cjson.encode(lead))
        count = count + 1
        redis.call('HINCRBY', campaign_stats_key, 'total_leads', 1)
        table.insert(new_active_leads, lead)
      else
        log('lead.voter_list_id('..lead.voter_list_id..') ~= list_id('..list_id..')')
        -- lead does not belong to target list, so leave in inactive
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
        copy_household_primitives(inactive_household, active_household)
      end
      active_household.leads = new_active_leads
      add_to_set(leads_added, active_household, phone)
      _active_household = cjson.encode(active_household)
      log('calling HSET with: '..active_key..', '..hkey..', '.._active_household)
      redis.call('HSET', active_key, hkey, _active_household)
      redis.call('HINCRBY', campaign_stats_key, 'total_numbers', 1)
    end
  end
end

log('END enable_leads.lua')

return count 

