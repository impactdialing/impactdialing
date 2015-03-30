web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb

app_health: rake environment monitor_app_health APP_HEALTH_RUN_INTERVAL=90

clock: rake environment resque:scheduler VERBOSE=true

call_flow: bundle exec sidekiq -c 8 -q call_flow LIBRATO_AUTORUN=1
dialer_loop: bundle exec ruby lib/dialer_loop.rb
dialer_worker: rake environment TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10 resque:work QUEUE=dialer_worker
simulator_loop: bundle exec ruby simulator/simulator_loop.rb
simulator_worker: rake environment TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10 resque:work QUEUE=simulator_worker

upload_download: rake environment resque:work TERM_CHILD=1 RESQUE_TERM_TIMEOUT=5 QUEUE=upload_download

background_worker: rake environment resque:work QUEUE=background_worker

persist_worker: rake environment resque:work QUEUE=persist_jobs

twilio_stats: rake environment resque:work QUEUE=twilio_stats

migration_worker: rake environment resque:work QUEUE=data_migrations RESQUE_TERM_TIMEOUT=10 TERM_CHILD=1
