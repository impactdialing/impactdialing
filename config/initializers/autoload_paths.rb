Rails.application.config.autoload_paths += %W(#{config.root}/jobs)
Rails.application.config.autoload_paths += %W(#{config.root}/app/concerns)
Rails.application.config.autoload_paths += %W(#{config.root}/app/models/redis)
