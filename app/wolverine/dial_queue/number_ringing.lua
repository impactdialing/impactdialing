redis.call('HINCRBY', KEYS[1], 'presented', -1)
redis.call('HINCRBY', KEYS[1], 'ringing', 1)
