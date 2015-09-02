local active_key       = KEYS[1]
local inactive_key     = KEYS[3]
local message_drop_key = KEYS[4]
local phone            = ARGV[1]
local hkey             = ARGV[2]
local bit              = 0

local _household = redis.call('HGET', active_key, hkey)
if _household == nil then
  _household = redis.call('HGET', inactive_key, hkey)
end

if _household ~= nil then
  local household = cjson.decode(_household)
  bit = redis.call('GETBIT', message_drop_key, household.sequence)
end

return bit
