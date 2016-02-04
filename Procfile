web: bundle exec puma -C config/puma.rb

app_health: rake environment monitor_app_health APP_HEALTH_RUN_INTERVAL=90

scheduler: bundle exec rake environment scheduler:run

call_flow: bundle exec sidekiq -c 8 -q call_flow LIBRATO_AUTORUN=1

persistence: bundle exec sidekiq -c 4 -q persistence LIBRATO_AUTORUN=1

clock: rake environment resque:scheduler

twilio_stats: rake environment resque:work QUEUE=twilio_stats TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10

dialer_worker: rake environment resque:work QUEUE=dialer_worker TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10

simulator_worker: rake environment resque:work QUEUE=simulator_worker TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10

reports: rake environment resque:work QUEUE=reports TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10

general: rake environment resque:work QUEUE=general TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10

dial_queue: rake environment resque:work QUEUE=dial_queue TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10

billing: rake environment resque:work QUEUE=billing TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10

import: rake environment resque:work QUEUE=import TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10
