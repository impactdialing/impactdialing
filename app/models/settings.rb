class Settings < Settingslogic
  if Rails.env == 'heroku'
    source "#{Rails.root}/config/application_heroku.yml"
  elsif Rails.env == 'heroku_staging'
    source "#{Rails.root}/config/application_heroku_staging.yml"
  else
    source "#{Rails.root}/config/application.yml"
  end
  namespace Rails.env
end
