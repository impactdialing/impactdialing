default: &default_settings
  host: beta-twilio.impactdialing.com
  public_host: www.beta.impactdialing.com
  port: 80
  phone: 8886215779

development:
  phone: 8582254595
  <<: *default_settings

test:
  <<: *default_settings

heroku_preproduction:
  <<: *default_settings
  host: beta-twilio.impactdialing.com
  port: 80

production:
  <<: *default_settings
  host: impactkungfupushupsclient.impactdialing.com
  port: 80

staging:
  <<: *default_settings
  phone: 8133640628
  host: staging.impactdialing.com
  port: 80

preproduction:
  <<: *default_settings
  phone: 8133640628
  host: twilio.impactdialing.com
  port: 80