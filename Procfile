web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb

app_health: rake environment monitor_app_health APP_HEALTH_RUN_INTERVAL=90

clock: rake environment resque:scheduler VERBOSE=true

dialer_loop: bundle exec ruby lib/dialer_loop.rb

simulator_loop: bundle exec ruby simulator/simulator_loop.rb

persist_worker: rake environment resque:work QUEUE=persist_jobs

twilio_stats: rake environment resque:work QUEUE=twilio_stats

call_flow: bundle exec sidekiq -c 8 -q call_flow LIBRATO_AUTORUN=1

dialer_worker: rake environment TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10 resque:work QUEUE=dialer_worker

simulator_worker: rake environment TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10 resque:work QUEUE=simulator_worker

reports: rake environment resque:work QUEUE=reports TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10

general: rake environment resque:work QUEUE=general TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10

dial_queue: rake environment resque:work QUEUE=dial_queue TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10

billing: rake environment resque:work QUEUE=billing TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10
