local n                 = ARGV[1]
local timestamp         = ARGV[2]
local active_key        = KEYS[1]
local presented_key     = KEYS[2]
local next_members      = redis.call('ZRANGE', active_key, 0, n-1, 'WITHSCORES') -- = > [phone,score,phone,score,...]
local next_phones       = {}
local presented_members = {}
local presented_phone   = nil

for i,phone_on_odds in pairs(next_members) do
  if i % 2 ~= 0 then
    -- build list of phones for return to client
    table.insert(next_phones, phone_on_odds)
    -- build list for move to presented zset
    presented_phone = phone_on_odds
  end

  -- update scores for presented zset
  if i % 2 == 0 then
    local old_score = phone_on_odds
    local new_score = timestamp
    table.insert(presented_members, new_score)
    table.insert(presented_members, presented_phone)
    presented_phone = nil
  end
end

if #next_phones > 0 then
  redis.call('ZADD', presented_key, unpack(presented_members))
  redis.call('ZREM', active_key, unpack(next_phones))
end

return cjson.encode(next_phones)
