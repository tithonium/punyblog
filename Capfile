load 'deploy'
require 'bundler/capistrano'

default_run_options[:pty]   = true  # Must be set for the password prompts to work
ssh_options[:forward_agent] = true  # Don't require keys on intermediate ssh hops

set :scm, :git
set :repository,  "git@github.com:tithonium/punyblog.git"
set :branch, "master"
set :deploy_via, :remote_cache

role :app,  "sarin.midgard.org"
role :web,  "sarin.midgard.org"
role :db,   "sarin.midgard.org", :primary => true, :no_release => true
role :cron, "sarin.midgard.org", :no_release => true

set :application, "martian_cc"
set :deploy_to, "/var/www/cc/martian/www"
set :user, "martian"
set :use_sudo, false
set :normalize_asset_timestamps, false

set :keep_releases, 3
after "deploy", "deploy:cleanup"

namespace :deploy do
  desc "N/A"
  task :start do
  end
  
  desc "N/A"
  task :stop do
  end
  
  desc "Tells Passenger to restart the application"
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end

namespace :configuration do
  
  config_files = %w[database.yml]
  
  desc "Upload non-committed files to shared/config"
  task :upload_files, :except => { :no_release => true } do
    run "mkdir -p #{shared_path}/config"
    config_files.each do |fn|
      file = File.expand_path("../config/#{fn}", __FILE__)
      upload(file.to_s, "#{shared_path}/config/#{fn}")
    end
    puts "If you have changed the configurations, you will need to restart the service."
  end
  
  desc "Download non-committed files from shared/config"
  task :download_files, :except => { :no_release => true } do
    run "mkdir -p #{shared_path}/config"
    config_files.each do |fn|
      file = File.expand_path("../config/#{fn}", __FILE__)
      download("#{shared_path}/config/#{fn}", file.to_s)
    end
  end
  
  desc "Symlink files in shared/config to current"
  task :symlink, :except => { :no_release => true } do
    run "ln -fs " + config_files.collect{|fn| "#{shared_path}/config/#{fn}" }.join(' ') + " #{release_path}/config/"
  end
  after "deploy:finalize_update", "configuration:symlink"
  
end
