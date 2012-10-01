class Settings < Settingslogic
  if Rails.env == 'heroku_preproduction'
    source "#{Rails.root}/config/application_heroku_preproduction.yml"
  elsif Rails.env == 'heroku_staging'
    source "#{Rails.root}/config/application_heroku_staging.yml"
  else
    source "#{Rails.root}/config/application.yml"
  end
  namespace Rails.env
end
