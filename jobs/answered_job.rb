require 'resque/plugins/lock'
require 'resque-loner'
require 'librato_resque'

##
# Persist answer data submitted to redis via web-ui.
# When answer data is submitted, it is stored in redis until
# this job runs and persists it to the relational database.
# This job only handles answer data submitted via the web-ui.
#
# ### Metrics
#
# - completed
# - failed
# - timing
# - sql timing
#
# ### Monitoring
#
# Alert conditions:
#
# - stops reporting for 5 minutes
#
# todo: stop rescuing Exception
#
class AnsweredJob
  include Resque::Plugins::UniqueJob
  extend LibratoResque
  
  @queue = :persist_jobs

  def self.perform
    ActiveRecord::Base.verify_active_connections!

    CallAttempt.results_not_processed.where('call_id IS NOT NULL AND voter_id IS NOT NULL').reorder('call_attempts.id DESC').includes(:call, :voter).find_each do |call_attempt|
      call = call_attempt.call
      answers_data = RedisCall.questions_and_notes(call.id)
      if answers_data && (answers_data["questions"] || answers_data["notes"])
        questions = answers_data["questions"]
        notes     = answers_data["notes"]

        call_attempt.voter.persist_answers(questions, call_attempt)
        call_attempt.voter.persist_notes(notes, call_attempt)
        call_attempt.update_attributes(voter_response_processed: true)
        call_attempt.voter.update_attribute(:result_date, Time.now)

        RedisCall.delete(call.id)
      else
        if call_attempt.created_at < 10.minutes.ago
          call_attempt.update_column(:voter_response_processed, true)
        end
      end
    end
  end
end
