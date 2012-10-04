web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb

dialer_loop: bundle exec ruby lib/dialer_loop.rb
simulator_loop: bundle exec ruby simulator/simulator_loop.rb

dialer_worker: rake environment TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10 resque:work QUEUE=dialer_worker
simulator_worker: rake environment TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10 resque:work QUEUE=simulator_worker

list_upload: rake environment resque:work TERM_CHILD=1 RESQUE_TERM_TIMEOUT=5 QUEUE=list_upload
report_download: rake environment resque:work TERM_CHILD=1 RESQUE_TERM_TIMEOUT=5 QUEUE=report_download

background_worker: rake environment resque:work QUEUE=background_worker

answered_worker: rake environment TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10 resque:work QUEUE=answered_worker
debit_worker: rake environment resque:work QUEUE=debit_worker

call_flow: rake environment TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10 resque:work QUEUE=call_flow
call_end: rake environment TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10 resque:work QUEUE=call_end

moderator_flow: rake environment TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10 resque:work QUEUE=moderator_flow

clock: rake environment resque:scheduler
