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

call_flow: bundle exec sidekiq -c 8 -q call_flow
persist_worker: rake environment resque:work QUEUE=persist_jobs
persist_worker_phones: rake environment resque:work QUEUE=persist_jobs_phones_only


twilio_stats_session: rake environment resque:work QUEUE=twilio_stats_session
twilio_stats_attempt: rake environment resque:work QUEUE=twilio_stats_attempt


clock: rake environment resque:scheduler
