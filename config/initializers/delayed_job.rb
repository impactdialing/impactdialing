Delayed::Worker.logger = Rails.logger
Delayed::Worker.destroy_failed_jobs = true
Delayed::Worker.sleep_delay = 60
Delayed::Worker.delay_jobs = !Rails.env.test?