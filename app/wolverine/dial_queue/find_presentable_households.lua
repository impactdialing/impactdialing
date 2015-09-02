local active_key          = KEYS[1]
local presented_key       = KEYS[2]
local completed_leads_key = KEYS[4]
local phone               = ARGV[1]
local hkey                = ARGV[2]
local _household          = redis.call('HGET', active_key, hkey)
local household           = cjson.decode(_household)
local available_leads     = {}

if household.leads then
  for _,lead in pairs(household.leads) do
    local completed_bit = redis.call('GETBIT', completed_leads_key, lead.sequence)
    if completed_bit == 0 then
      table.insert(available_leads, lead)
    end
  end

  household.leads = available_leads
  _household = cjson.encode(household)

  redis.call('HSET', presented_key, hkey, _household)
else
  _household = ''
end

return _household
