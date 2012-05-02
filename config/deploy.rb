require 'bundler/capistrano'
require "delayed/recipes"

repository = 'git@github.com:impactdialing/Impact-Dialing.git'
bundle_flags = '--deployment --quiet --binstubs'
bundle_without = [:development, :test, :darwin, :linux]
preproduction_server = 'ec2-50-16-66-123.compute-1.amazonaws.com'
staging_server = 'ec2-174-129-172-31.compute-1.amazonaws.com'
set :application, 'impactdialing'
set :user, 'rails'
set :scm, :git
set :scm_auth_cache, true
set :repository, repository
set :runner, 'rails'
set :use_sudo, false
set :deploy_via, :export
set :deploy_to, "/var/www/rails/#{application}"
set :chmod755, 'app config db lib public vendor script script/* public/ disp*'
set :bundle_without, bundle_without
set :bundle_flags, bundle_flags
set :delayed_job_server_role, :app

namespace :deploy do
  task :bundle_new_release, :roles => :app do
    run "cd #{deploy_to} && bundle install --without #{bundle_without.join(' ')} #{bundle_flags}"
    run "cd #{deploy_to}/simulator && bundle install --without #{bundle_without.join(' ')} #{bundle_flags}"
  end

  task :restart, :roles => :app do
    run "touch #{deploy_to}/current/tmp/restart.txt"
  end

  after('deploy:symlink', 'deploy:link_configuration')
  after('deploy:symlink', 'deploy:install_cron_jobs')
  after('deploy:symlink', 'deploy:restart_dialer')
  after('deploy:symlink', 'deploy:restart_delayed_job_worker')
  after('deploy:symlink', 'deploy:restart_simulator')
  after('deploy:link_configuration', 'deploy:migrate')

  task :link_configuration, :roles => :app do
    run "ln -s #{deploy_to}/shared/config/database.yml #{current_path}/config/database.yml"
    run "ln -s #{deploy_to}/shared/config/database.yml #{current_path}/simulator/database.yml"
    run "ln -s #{deploy_to}/shared/config/application.yml #{current_path}/config/application.yml"
  end

  task :install_cron_jobs do
    run "chmod a+x #{current_path}/script/configure_crontab.sh"
    run "#{current_path}/script/configure_crontab.sh #{rails_env} #{deploy_to}"
  end

  task :restart_dialer do
    run "ps -ef | grep 'predictive_dialer' | grep -v grep | awk '{print $2}' | xargs kill || echo 'no process with name predictive_dialer found'"
    run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec script/predictive_dialer_control.rb start"
  end

  task :restart_delayed_job_worker do
    run "ps -ef | grep 'delayed_job' | grep -v grep | awk '{print $2}' | xargs kill || echo 'no process with name delayed_job found'"
    run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec script/delayed_job start"
  end

  task :restart_simulator do
    run "ps -ef | grep 'simulator' | grep -v grep | awk '{print $2}' | xargs kill || echo 'no process with name simulator found'"
    run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec simulator/simulator_control.rb start"
  end
end

task :staging do
  set :server_name, staging_server
  set :rails_env, 'staging'
  set :branch, 'predictive'
  role :web, staging_server
  role :app, staging_server
  role :db, staging_server, :primary => true
end

task :preproduction do
  set :rails_env, 'preproduction'
  set :branch, 'preproduction'
  role :web, preproduction_server
  role :app, preproduction_server
  role :db, preproduction_server, :primary => true #use an app server for migrations
end

task :production do
  set :rails_env, 'production'
  set :branch, 'temp_production'
  role :web, 'ec2-107-20-17-151.compute-1.amazonaws.com'
  role :app, 'ec2-107-20-17-151.compute-1.amazonaws.com'
  role :db, 'ec2-107-20-17-151.compute-1.amazonaws.com', :primary => true #use an app server for migrations
end

task :search_libs, :hosts => 'ec2-75-101-228-54.compute-1.amazonaws.com', :user=>'ubuntu' do
  set :user, 'ubuntu'
  run 'ls -x1 /usr/lib | grep -i xml'
end

        require './config/boot'
        require 'airbrake/capistrano'
