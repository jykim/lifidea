# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_ddl_session',
  :secret      => 'eb5a613654128de603c4a2a69cdc666d5eda0436368a74179862841e4ba44f29f440deeca5890c68510ca5d4657385ae50d9e8d47244e94cb8a388c0a7ee2f85'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
