web:  bundle exec rails server thin -p $PORT

dialer_loop: bundle exec ruby lib/dialer_loop.rb
simulator_loop: bundle exec ruby simulator/simulator_loop.rb

dialer_worker: rake environment resque:work QUEUE=dialer
simulator_worker: rake environment resque:work QUEUE=simulator

voter_list_upload_worker_job: rake environment resque:work QUEUE=voter_list_upload_worker_job
report_download_worker_job: rake environment resque:work QUEUE=report_download_worker_job

background_worker_job: rake environment resque:work QUEUE=background_worker_job

answered_worker_job: rake environment resque:work QUEUE=answered_worker
debit_worker_job: rake environment resque:work QUEUE=debit_worker

call_flow: rake environment resque:work QUEUE=call_flow
call_end: rake environment resque:work QUEUE=call_end

moderator_flow: rake environment resque:work QUEUE=moderator_caller
moderator_flow: rake environment resque:work QUEUE=moderator_call

clock:   rake environment resque:scheduler
