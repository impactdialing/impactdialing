for _,key in pairs(KEYS) do
  redis.call('DEL', key)
end
