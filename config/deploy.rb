require "bundler/capistrano"

repository = "https://impact-dialing.svn.beanstalkapp.com/webapp/trunk"
set :application, "impactdialing"
set :user, "rails"
set :scm, :subversion
set :scm_auth_cache, true
set :deploy_via, :export
set :repository,  repository
set :runner, 'rails'
set :use_sudo, false
set :deploy_via, :export
set :deploy_to, "/var/www/rails/#{application}"
set :chmod755, "app config db lib public vendor script script/* public/ disp*"

namespace :deploy do
  task :restart, :roles => :app do
    run "touch #{deploy_to}/current/tmp/restart.txt"
  end

  after('deploy:symlink', 'deploy:link_configuration')

  task :link_configuration, :roles => :app do
    run "ln -s #{deploy_to}/shared/config/database.yml #{current_path}/config/database.yml"
  end
end

task :production do
  set :server_name, "domU-12-31-39-09-65-F3.compute-1.internal"
  set :rails_env, 'production'
end

task :staging do
  set :server_name, "ec2-174-129-172-31.compute-1.amazonaws.com"
  set :rails_env, 'staging'
  role :web, 'staging.impactdialing.com'
  role :app, 'staging.impactdialing.com'
  role :db, 'staging.impactdialing.com', :primary => true
end
