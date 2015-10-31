local hash_keys = cjson.decode(ARGV[1])

for i,key in pairs(KEYS) do
  redis.call('HDEL', key, hash_keys[i])
end
