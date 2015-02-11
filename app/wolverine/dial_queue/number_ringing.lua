local counts = {}

table.insert(counts, redis.call('HGET', KEYS[1], 'presented'))
table.insert(counts, redis.call('HGET', KEYS[1], 'ringing'))

local presented_count = redis.call('HINCRBY', KEYS[1], 'presented', -1)
local ringing_count   = redis.call('HINCRBY', KEYS[1], 'ringing', 1)

table.insert(counts, presented_count)
table.insert(counts, ringing_count)

return counts