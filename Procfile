web:  bundle exec rails server thin -p $PORT 
worker:  rake environment jobs:work
dialer: bundle exec ruby lib/predictive_dialer.rb
new_simulator: bundle exec ruby simulator/newest_simulator.rb
debiter: bundle exec ruby lib/debit.rb
answers: bundle exec ruby lib/process_voter_response.rb

