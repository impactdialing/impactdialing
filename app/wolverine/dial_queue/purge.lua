-- dial queue contract guarantees that only households w/ corresponding
-- numbers in either available or recycle bin zsets will be stored in redis
-- this means we don't need to worry about looking up keys because
-- we can rely on the zets as a canonical source
local sets = {}
local purged_count = 0

for _,key in pairs(KEYS) do
  sets[#sets + 1] = redis.call("ZRANGE", key, "0", "-1")
end

for _,set in pairs(sets) do
  for _,phone in pairs(set) do
    -- delete hashes
    local key = ARGV[1] .. ":" .. string.sub(phone, 1, tonumber(ARGV[2]))
    redis.call("DEL", key)
    purged_count = purged_count + 1
  end
end

-- delete the sets
for _,key in pairs(KEYS) do
  redis.call("DEL", key)
end

return purged_count
