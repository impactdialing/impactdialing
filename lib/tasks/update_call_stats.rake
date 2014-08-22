if Rails.env.development?
  task :update_call_stats => :environment do
    require 'impact_platform'
    # persist call data from redis
    PersistCalls.perform
    PersistPhonesOnlyAnswers.perform
    AnsweredJob.perform

    # fetch call data from Twilio
    UpdateTwilioStatsCallerSession.perform
    UpdateStatsAttemptsEm.perform
    UpdateStatsTransfersEm.perform
  end
end
