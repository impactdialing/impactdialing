web:  bundle exec rails server thin -p $PORT 
dialer: bundle exec ruby lib/predictive_dialer.rb
new_simulator: bundle exec ruby simulator/newest_simulator.rb
worker_job: rake environment resque:work QUEUE=worker_job
background_worker_job: rake environment resque:work QUEUE=background_worker_job
clock:   rake environment resque:scheduler


