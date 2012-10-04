web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb

dialer_loop: bundle exec ruby lib/dialer_loop.rb
simulator_loop: bundle exec ruby simulator/simulator_loop.rb

dialer_worker: rake environment resque:work QUEUE=dialer_worker
simulator: rake environment resque:work QUEUE=simulator

list_upload: rake environment resque:work QUEUE=list_upload
report_download: rake environment resque:work QUEUE=report_download

background_worker: rake environment resque:work QUEUE=background_worker

answered_worker: rake environment resque:work QUEUE=answered_worker
debit_worker: rake environment resque:work QUEUE=debit_worker

call_flow: bundle exec sidekiq -c 20 -q call_flow
call_end: bundle exec sidekiq -c 20 -q call_end

moderator_flow: bundle exec sidekiq -c 20 -q moderator_flow

clock: rake environment resque:scheduler
