web: bundle exec rails server thin -p $PORT

dialer_loop: bundle exec ruby lib/dialer_loop.rb
simulator_loop: bundle exec ruby simulator/simulator_loop.rb

dialer_worker: rake environment resque:work QUEUE=dialer_worker
simulator_worker: rake environment resque:work QUEUE=simulator_worker

list_upload: rake environment resque:work QUEUE=list_upload
report_download: rake environment resque:work QUEUE=report_download

background_worker: rake environment resque:work QUEUE=background_worker

answered_worker: rake environment resque:work QUEUE=answered_worker
debit_worker: rake environment resque:work QUEUE=debit_worker

call_flow: rake environment resque:work QUEUE=call_flow
call_end: rake environment resque:work QUEUE=call_end

moderator_flow: rake environment resque:work QUEUE=moderator_flow

clock: rake environment resque:scheduler
