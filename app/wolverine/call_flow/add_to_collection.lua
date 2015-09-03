local key             = KEYS[1]
local collection_name = ARGV[1]
local new_items       = cjson.decode(ARGV[2])
local items           = {}
local _items          = redis.call('HGET', key, collection_name)
if _items then
  items = cjson.decode(_items)
end

for _,item in pairs(new_items) do
  table.insert(items, item)
end

_items = cjson.encode(items)
redis.call('HSET', key, collection_name, _items)
