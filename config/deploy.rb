require "bundler/capistrano"

server_name = "ec2-174-129-172-31.compute-1.amazonaws.com"
repository = "https://impact-dialing.svn.beanstalkapp.com/webapp/trunk"
set :application, "impactdialing"
set :server_name, server_name
set :user, "rails"
set :scm, :subversion
set :scm_username, "srushti"
set :scm_auth_cache, true
set :deploy_via, :export
set :repository,  repository
set :runner, 'rails'
set :use_sudo, false
set :deploy_via, :export
set :deploy_to, "/var/www/rails/#{application}"
set :chmod755, "app config db lib public vendor script script/* public/ disp*"
set :rails_env, 'production'
role :web, 'stagingimpactdialing.com'
role :app, 'stagingimpactdialing.com'
role :db, 'stagingimpactdialing.com'

namespace :deploy do
  task :restart, :roles => :app do
    run "touch #{deploy_to}/current/tmp/restart.txt"
  end

  after('deploy:symlink', 'deploy:link_configuration')

  task :link_configuration, :roles => :app do
    run "ln -s #{deploy_to}/shared/config/database.yml #{current_path}/config/database.yml"
  end
end
