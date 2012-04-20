# --- Version Store
# All Workers that use the Record Cache should point to the same Version Store
# E.g. a MemCached cluster or a Redis Store (defaults to Rails.cache)
if Rails.env == 'heroku' || Rails.env == "heroku_staging"
  RecordCache::Base.version_store = Rails.cache
  RecordCache::Base.register_store(:local, Rails.cache)
  RecordCache::Base.register_store(:shared, Rails.cache)
else
  RecordCache::Base.version_store = Rails.cache
  RecordCache::Base.register_store(:local, Rails.cache)
  RecordCache::Base.register_store(:shared, Rails.cache)
  
end  