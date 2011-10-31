require "bundler/capistrano"

repository = "git@github.com:impactdialing/Impact-Dialing.git"
set :application, "impactdialing"
set :user, "rails"
set :scm, :git
set :scm_auth_cache, true
set :repository,  repository
set :runner, 'rails'
set :use_sudo, false
set :deploy_via, :export
set :deploy_to, "/var/www/rails/#{application}"
set :chmod755, "app config db lib public vendor script script/* public/ disp*"
set :bundle_without,  [:development, :test, :darwin, :linux]
set :bundle_flags,    "--deployment --quiet --binstubs"

namespace :deploy do
  task :bundle_new_release, :roles => :app do
    run "cd #{deploy_to} && bundle install --without test"
  end

  task :restart, :roles => :app do
    run "touch #{deploy_to}/current/tmp/restart.txt"
  end

  after('deploy:symlink', 'deploy:link_configuration')
  after('deploy:symlink', 'deploy:install_cron_jobs')
  after('deploy:link_configuration', 'deploy:migrate')

  task :link_configuration, :roles => :app do
    run "ln -s #{deploy_to}/shared/config/database.yml #{current_path}/config/database.yml"
  end

  task :install_cron_jobs do
    run "chmod a+x #{current_path}/script/configure_crontab.sh"
    run "#{current_path}/script/configure_crontab.sh #{rails_env} #{deploy_to}"
  end
end

task :staging do
  set :server_name, "ec2-174-129-172-31.compute-1.amazonaws.com"
  set :rails_env, 'staging'
  set :branch, "temp_production"
  role :web, 'ec2-174-129-172-31.compute-1.amazonaws.com'
  role :app, 'ec2-174-129-172-31.compute-1.amazonaws.com'
  role :db, 'ec2-174-129-172-31.compute-1.amazonaws.com', :primary => true
end

task :production do
  set :rails_env, 'production'
  role :web, 'ec2-107-20-17-151.compute-1.amazonaws.com', 'ec2-184-73-34-159.compute-1.amazonaws.com'
  role :app, 'ec2-107-20-17-151.compute-1.amazonaws.com', 'ec2-184-73-34-159.compute-1.amazonaws.com'
  role :db, 'ec2-107-20-17-151.compute-1.amazonaws.com', :primary => true #use an app server for migrations
end

task :search_libs, :hosts => "ec2-75-101-228-54.compute-1.amazonaws.com", :user=>"ubuntu" do
  set :user, "ubuntu"
  run "ls -x1 /usr/lib | grep -i xml"
end
