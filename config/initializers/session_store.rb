# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_impactdialing_session',
  :secret      => 'a6a216284084d10f15c693880b7ce6f7e6fb78c741583f5bc75de258c48caed2a702ffbee81428a3d5183df16527b83645434cc4fdb58b6d3939783a4e6c38b9'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
