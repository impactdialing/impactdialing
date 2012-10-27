#
# Put here shared configuration shared among all children
#
# Read more about configurations:
# https://github.com/railsware/capistrano-multiconfig/README.md

# Configuration example for layout like:
# config/deploy/{NAMESPACE}/.../#{PROJECT_NAME}/{STAGE_NAME}.rb

ssh_options[:forward_agent] = true
default_run_options[:pty] = true

set :scm, :git

set :git_shallow_clone, 1

set :deploy_via, :export

set :branch, lambda { Capistrano::CLI.ui.ask "SCM branch: " }

set(:stage) { config_name.split(':').last }

set(:rails_env) { stage }

set :rake, "bundle exec rake --trace"

set(:repository) { "git@github.com:impactdialing/Impact-Dialing.git" }

set(:deploy_to) { "/var/www/impactdialing" }

set :use_sudo, false

set :keep_releases, 5

set :bundle_flags,    "--quiet"

namespace :deploy do  

  desc "Full deploy"
  task :default do
    transaction do
      deploy.update_code
      bundle.install
      deploy.symlink_database_config
      deploy.symlink
    end
    unicorn.start
    deploy.cleanup
  end
  
  task :symlink_database_config, :roles => :app do
    run <<-CMD
      ln -nfs #{release_path}/config/database.yml.sample #{release_path}/config/database.yml
    CMD
  end
end


namespace :unicorn do  
  task :reload, roles => :web do
    sudo "/etc/init.d/unicorn reload"
  end

  task :start, roles => :web do
    sudo "/etc/init.d/unicorn start"
  end

  task :stop, roles =>  :web do
    sudo "/etc/init.d/unicorn stop"
  end

  task :restart, roles => :web do
    sudo "/etc/init.d/unicorn restart"
  end
end
