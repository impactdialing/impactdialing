if ['heroku', 'aws'].include?(Rails.env)
  Recurly.api_key          = "cc3c96563b86477a8bbbfd01e696a1b9"
  Recurly.js.private_key   = "96f3b43f1f78425ca20d382a05d0f646"
  RECURLY_SUBDOMAIN        = "impact-dialing"
elsif ['heroku_staging', 'aws_staging'].include?(Rails.env)
  Recurly.api_key          = "57aafeeeaa0346f3ac6bfb35e9a03e56"
  Recurly.js.private_key   = "41e7be117eb54d41b1d144815cb04809"
  RECURLY_SUBDOMAIN        = "impact-staging"
else
  Recurly.api_key          = "16b631fa166a4c81ad9da59ea768cc88"
  Recurly.js.private_key   = "0c5819d214dd41ff94674c66d69a798a"
  RECURLY_SUBDOMAIN        = "impactdialing"
end
  

# Recurly.default_currency = 'USD'
