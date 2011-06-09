require "bundler/capistrano"

server_name = "ec2-50-19-57-159.compute-1.amazonaws.com"
repository = "https://impact-dialing.svn.beanstalkapp.com/webapp/trunk"
set :application, "impactdialing"
set :server_name, server_name
set :user, "root"
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
role :web, 'staging.impactdialing.com'
role :app, 'staging.impactdialing.com'
role :db, 'staging.impactdialing.com'

