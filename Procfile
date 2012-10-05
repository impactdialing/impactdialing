web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb

dialer_loop: bundle exec ruby lib/dialer_loop.rb
simulator_loop: bundle exec ruby simulator/simulator_loop.rb

dialer_worker: rake environment TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10 resque:work QUEUE=dialer_worker
simulator_worker: rake environment TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10 resque:work QUEUE=simulator_worker

list_upload: rake environment resque:work TERM_CHILD=1 RESQUE_TERM_TIMEOUT=5 QUEUE=list_upload
report_download: rake environment resque:work TERM_CHILD=1 RESQUE_TERM_TIMEOUT=5 QUEUE=report_download

background_worker: rake environment resque:work QUEUE=background_worker
alert_worker: rake environment resque:work QUEUE=alert_worker


answered_worker: rake environment TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10 resque:work QUEUE=answered_worker
debit_worker: rake environment resque:work QUEUE=debit_worker

call_flow: bundle exec sidekiq -c 20 -q call_flow
call_end: bundle exec sidekiq -c 20 -q call_end

moderator_flow: bundle exec sidekiq -c 20 -q moderator_flow


clock: rake environment resque:scheduler
monitor_worker: bundle exec ruby lib/monitor_tab_pusher.rb
connected_call_worker: bundle exec ruby lib/connected_call.rb