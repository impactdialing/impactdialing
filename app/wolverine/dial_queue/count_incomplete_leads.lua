local active_key            = KEYS[1]
local inactive_key          = KEYS[2]
local completed_leads_key   = KEYS[3]
local phone                 = ARGV[1]
local hkey                  = ARGV[2]
local incomplete_lead_count = 0

local _household = redis.call('HGET', active_key, hkey)
if _household == nil then
  _household = redis.call('HGET', inactive_key, hkey)
end

if _household then
  local household = cjson.decode(_household)
  local bit       = 0
  for _,lead in pairs(household.leads) do
    bit = redis.call('GETBIT', completed_leads_key, lead.sequence)
    if bit == 0 then
      incomplete_lead_count = incomplete_lead_count + 1
    end
  end
end

return incomplete_lead_count
