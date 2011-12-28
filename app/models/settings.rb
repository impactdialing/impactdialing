class Settings < Settingslogic
  if Rails.env == 'heroku'
    source "#{Rails.root}/config/application_heroku.yml"
  else
    source "#{Rails.root}/config/application.yml"
  end
  namespace Rails.env
end
