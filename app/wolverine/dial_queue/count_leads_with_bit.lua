local active_key   = KEYS[1]
local inactive_key = KEYS[3]
local bitmap_key   = KEYS[4]
local phone        = ARGV[1]
local hkey         = ARGV[2]
local target_bit   = tonumber(ARGV[3])
local lead_count   = 0

local _household = redis.call('HGET', active_key, hkey)

if _household then
  local household = cjson.decode(_household)
  local bit       = 0
  for _,lead in pairs(household.leads) do
    bit = redis.call('GETBIT', bitmap_key, lead.sequence)
    if bit == target_bit then
      lead_count = lead_count + 1
    end
  end
end

return lead_count
