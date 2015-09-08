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

log('disable_leads.lua START')

local merge_leads = function (lead, lead_id_set)
  lead_id_set[lead.custom_id] = lead
end

local copy_household_primitives = function(source_hh, dest_hh)
  for k,v in pairs(source_hh) do
    if k ~= 'leads' and v ~= nil and v ~= "" then
      log('updating active household '..k..' with '..v)
      dest_hh[k] = v
    end
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
      log('inactive leads merging'..cjson.encode(current_inactive_leads))
      for _,lead in pairs(current_inactive_leads) do
        log('inactive lead custom id: '..lead.custom_id..' lead: '..cjson.encode(lead))
        lead_id_set[lead.custom_id] = lead
      end
    else
      log('inactive leads not merging')
      log('current inactive leads'..cjson.encode(current_inactive_leads))
      new_inactive_leads = current_inactive_leads
    end

    for _,lead in pairs(current_active_leads) do
      if tonumber(lead.voter_list_id) == list_id then
        -- lead belongs to target list, so move to inactive
        if #lead_id_set ~= 0 then
          log('#lead_id_set ~= 0; merging')
          lead_id_set[lead.custom_id] = lead
        else
          log('no leads in lead_id_set to merge: #lead_id_set: '..#lead_id_set..' lead_id_set: '..cjson.encode(lead_id_set))
        end
        count = count + 1
        redis.call('HINCRBY', campaign_stats_key, 'total_leads', -1)
        table.insert(new_inactive_leads, lead)
      else
        log('lead.voter_list_id('..lead.voter_list_id..') ~= list_id('..list_id..') lead: '..cjson.encode(lead))
        -- lead does not belong to target list, so leave in active
        table.insert(new_active_leads, lead)
      end
    end

    local score = nil
    if #new_active_leads ~= 0 then
      log('new active leads found, leaving sets alone')
      active_household.leads = new_active_leads
      redis.call('HSET', active_key, hkey, cjson.encode(active_household))
    else
      log('no new active leads found, removing froms sets')
      -- household has no active leads from other lists
      -- record the score to use when enabling
      score = redis.call('ZSCORE', available_set_key, phone)
      if score then
        log('phone in available, score: '..tostring(score))
        redis.call('ZREM', available_set_key, phone)
        log('removed '..phone..' from available set')
      else
        score = redis.call('ZSCORE', recycle_bin_set_key, phone)
        log('phone in recycle bin, score: '..tostring(score))
        if score then
          redis.call('ZREM', recycle_bin_set_key, phone)
          log('removed '..phone..' from recycle bin set')
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
      log('saving inactive leads w/ score: '.. tostring(score))
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

log('disable_leads.lua END')

return count 

