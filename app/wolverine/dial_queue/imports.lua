local stats_key                 = KEYS[1]
local household_key_base        = ARGV[1] -- dial_queue:{campaign_id}:households:active
--local households              = cmsgpack.unpack(ARGV[1])
local households                = cjson.decode(ARGV[2])
local _updated_hh               = {}

for phone,household in pairs(households) do
  local household_key             = household_key_base .. ':' .. string.sub(phone, 0, -4)
  local phone_key                 = string.sub(phone, -3, -1)
  local new_leads                 = household['leads']
  local uuid                      = household['uuid']
  local updated_leads             = {}
  local leads                     = {}
  local current_hh                = {}
  local updated_hh                = {}
  local new_number_count          = 0
  local pre_existing_number_count = 0
  local new_lead_count            = 0
  local updated_lead_count        = 0
  local _current_hh               = redis.call('HGET', household_key, phone_key)

  if _current_hh then
    -- this household has been saved so merge
    -- current_hh = cmsgpack.unpack(_current_hh)
    current_hh = cjson.decode(_current_hh)

    -- hh attributes
    uuid = current_hh['uuid']

    -- leads
    local current_leads = current_hh['leads']
    
    if current_leads[1] and current_leads[1].custom_id ~= nil then
      -- handle updates, merge leads
      local lead_id_set   = {}
      for _,lead in pairs(current_leads) do
        lead_id_set[lead.custom_id] = lead
      end

      for _,lead in pairs(new_leads) do
        if lead_id_set[lead.custom_id] ~= nil then
          updated_lead_count = updated_lead_count + 1

          for k,v in pairs(lead) do
            if k ~= 'uuid' and k ~= 'custom_id' then
              lead_id_set[lead.custom_id][k] = v
            end
          end
        else
          new_lead_count = new_lead_count + 1
          lead_id_set[lead.custom_id] = lead
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
    end

    pre_existing_number_count = pre_existing_number_count + 1
  else
    -- brand new household
    for _,lead in pairs(new_leads) do
      new_lead_count = new_lead_count + 1
      table.insert(updated_leads, lead)
    end
    new_number_count = new_number_count + 1
  end

  updated_hh['leads'] = updated_leads
  updated_hh['uuid']  = uuid

  -- local _updated_hh = cmsgpack.pack(updated_hh)
  local _updated_hh = cjson.encode(updated_hh)

  redis.call('HSET', household_key, phone_key, _updated_hh)

  redis.call('HINCRBY', stats_key, 'new_leads', new_lead_count)
  redis.call('HINCRBY', stats_key, 'updated_leads', updated_lead_count)
  redis.call('HINCRBY', stats_key, 'new_numbers', new_number_count)
  redis.call('HINCRBY', stats_key, 'pre_existing_numbers', pre_existing_number_count)
  redis.call('EXPIRE',  stats_key, 86400)
end
