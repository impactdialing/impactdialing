local presented_key            = KEYS[2]
local completed_bitmap_key     = KEYS[4]
local dispositioned_bitmap_key = KEYS[5]
local phone                    = ARGV[1]
local hkey                     = ARGV[2]
local available_leads          = {}
local fresh_leads              = {}
local target_lead              = {}

local _household = redis.call('HGET', presented_key, hkey)

local collect_zero_bit_leads = function (bitmap_key, source, dest)
  for _,lead in pairs(source) do
    local bit = redis.call('GETBIT', bitmap_key, lead.sequence)
    if bit == 0 then
      table.insert(dest, lead)
    end
  end
end

local detect_lowest_sequence = function (leads)
  target_lead = leads[1]
  for _,lead in pairs(leads) do
    if target_lead.sequence > lead.sequence then
      target_lead = lead
    end
  end
end

if _household then
  local household = cjson.decode(_household)
  collect_zero_bit_leads(completed_bitmap_key, household.leads, available_leads)
  collect_zero_bit_leads(dispositioned_bitmap_key, available_leads, fresh_leads)

  if #fresh_leads > 0 then
    -- 1 or more leads have not been dispositioned
    detect_lowest_sequence(fresh_leads)
  else
    -- all leads have been dispositioned
    detect_lowest_sequence(available_leads)
  end
end

return cjson.encode(target_lead)

