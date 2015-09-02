local active_key       = KEYS[1]
local inactive_key     = KEYS[3]
local message_drop_key = KEYS[4]
local phone            = ARGV[1]
local hkey             = ARGV[2]
local bit              = 1
local household        = {}

local _household = redis.call('HGET', active_key, hkey)
if _household == nil then
  _household = redis.call('HGET', inactive_key, hkey)
end

if _household then
  local household = cjson.decode(_household)
  bit = redis.call('SETBIT', message_drop_key, household.sequence, 1)
end

return household.sequence
