loop processes
- app_health
- dialer_loop
- simulator_loop

resque job processes
- dialer_worker
- simulator_worker
- upload_download
- background_worker
- persist_worker
- twilio_stats
- migration_worker

sidekiq job processes
- call_flow

dialer_worker jobs
- CalculateDialsJob [SLOW]
- DialerJob [VERY SLOW]

simulator_worker jobs
- SimulatorJob [SLOW]

reports
- AdminReportJob [EXTREMELY SLOW] [ONTERM REQUEUE]
- ReportAccountUsageJob [EXTREMELY SLOW] [ONTERM REQUEUE]
- ReportDownloadJob [EXTREMELY SLOW] [ONTERM REQUEUE]

dial_queue
- CallFlow::DialQueue::Jobs::CacheVoters [SLOW] [CALL CRITICAL] [ONTERM REQUEUE]
- Archival::Jobs::CampaignRestored [queued from user action] [VERY EXTREMELY SLOW] [CALL CRITICAL] [ONTERM REQUEUE]
- VoterListChangeJob [SLOW] [ONTERM REQUEUE]
- VoterListUploadJob [EXTREMELY SLOW] [ONTERM REQUEUE]
- CallFlow::Jobs::PruneHouseholds [ONTERM REQUEUE]
- CallerGroupJob [SLOW] [CALL CRITICAL] [ONTERM REQUEUE]
- CallFlow::Web::Jobs::CacheContactFields [FAST] [CALL CRITICAL]
- CachePhonesOnlyScriptQuestions [FAST] [CALL CRITICAL]
- DoNotCall::Jobs::BlockedNumberCreated [FAST]
- DoNotCall::Jobs::BlockedNumberDestroyed [FAST]
- CallFlow::DialQueue::Jobs::Recycle [Scheduled] [SLOW] [CALL CRITICAL]

general
- DoNotCall::Jobs::CachePortedLists [Scheduled nightly] [VERY SLOW]
- DoNotCall::Jobs::CacheWirelessBlockList [Scheduled nightly] [VERY SLOW]
- DoNotCall::Jobs::RefreshPortedLists [Scheduled nightly] [VERY SLOW]
- DoNotCall::Jobs::RefreshWirelessBlockList [Scheduled nightly] [VERY SLOW]
- Archival::Jobs::CampaignSweeper [Scheduled nightly] [SLOW]
- Archival::Jobs::CampaignArchived [queued from CampaignSweeper or user action] [FAST]
- CallFlow::DialQueue::Jobs::Purge [queued from CampaignArchived] [FAST]
- ResetVoterListCounterCache [FAST]
- PhantomCallerJob [Scheduled] [FAST]
- DeliverInvitationEmailJob [FAST]
- ResetPasswordEmailJob [FAST]

billing
- Billing::Jobs::AutoRecharge [??] [CALL CRITICAL] [ONTERM REQUEUE]
- Billing::Jobs::StripeEvent [??] [CALL CRITICAL] [ONTERM REQUEUE]
- DebitJob [Scheduled] [FAST] [CALL CRITICAL]

persist_worker jobs
- AnsweredJob [Scheduled] [SLOW] [CALL CRITICAL]
- PersistCalls [Scheduled] [SLOW] [CALL CRITICAL]
- PersistPhonesOnlyAnswers [Scheduled] [FAST] [CALL CRITICAL]

twilio_stats jobs
- UpdateStatsAttemptsEm [Scheduled] [FAST]
- UpdateStatsTransfersEm [Scheduled] [FAST]
- UpdateTwilioStatsCallerSession [Scheduled] [FAST]

call_flow jobs [ALL CALL CRITICAL]
- CallerPusherJob [EXTREMELY FAST]
- PreviewPowerDialJob [SLOW]
- RedirectCallerJob [SLOW]
- Providers::Phone::Jobs::DropMessageRecorder [EXTREMELY FAST]
- Providers::Phone::Jobs::DropMessage [SLOW]
- VoterConnectedPusherJob [FAST]
- EndRunningCallJob [SLOW]
- EndCallerSessionJob [EXTREMELY FAST]
- CampaignOutOfNumbersJob [FAST]


