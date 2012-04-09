web:  bundle exec unicorn -p $PORT -c ./config/unicorn.rb 
worker:  rake environment jobs:work
dialer: bundle exec ruby lib/predictive_dialer.rb
simulator: bundle exec ruby simulator/new_simulator.rb
new_simulator: bundle exec ruby simulator/newest_simulator.rb
download: bundle exec ruby simulator/report_download.rb