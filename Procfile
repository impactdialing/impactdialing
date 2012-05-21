web:  bundle exec rails server thin -p $PORT 
dialer: bundle exec ruby lib/predictive_dialer.rb
new_simulator: bundle exec ruby simulator/newest_simulator.rb
list_upload_worker: rake environment resque:work QUEUE=voter_list
report_download_worker: rake environment resque:work QUEUE=report_download
debiter: bundle exec ruby lib/debit.rb
answers: bundle exec ruby lib/process_voter_response.rb

