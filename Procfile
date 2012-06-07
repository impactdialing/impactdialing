web:  bundle exec rails server thin -p $PORT 
dialer: bundle exec ruby lib/predictive_dialer.rb
new_simulator: bundle exec ruby simulator/newest_simulator.rb
worker:  rake environment jobs:work
report_download_worker: rake environment resque:work QUEUE=worker_job
debiter: bundle exec ruby lib/debit.rb
answers: bundle exec ruby lib/process_voter_response.rb

