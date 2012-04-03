if Rails.env == 'heroku'
  Recurly.api_key          = "16b631fa166a4c81ad9da59ea768cc88"
  Recurly.js.private_key   = "0c5819d214dd41ff94674c66d69a798a"
elsif Rails.env == 'staging'
  Recurly.api_key          = "48b67eea45ec4f24b90c9544bb04d327"
  Recurly.js.private_key   = "37f764140f4a44d3938e4bc9b24ccab5"
else
  Recurly.api_key          = "16b631fa166a4c81ad9da59ea768cc88"
  Recurly.js.private_key   = "0c5819d214dd41ff94674c66d69a798a"
end
  

# Recurly.default_currency = 'USD'
