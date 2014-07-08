require 'resque/errors'
require 'impact_platform/heroku'

class VoterListChangeJob
  @queue = :upload_download
  extend UploadDownloadHooks

  def self.perform(voter_list_id, enabled)
    begin
      p "VoterListChangeJob performing..."
      voter_list = VoterList.find(voter_list_id)
      voter_list.voter_ids.each_slice(500) do |ids|
        Voter.where(id: ids).update_all(enabled: enabled)
      end
      p "VoterListChangeJob done."
    rescue Resque::TermException, ActiveRecord::StatementInvalid => exception
      handle_exception(voter_list_id, enabled, exception)
    end
  end

  def self.requeue(voter_list_id, enabled)
    Resque.enqueue(self, voter_list_id, enabled)
  end

  def self.handle_exception(voter_list_id, enabled, exception)
    if exception.kind_of? ActiveRecord::StatementInvalid
      mailer         = ExceptionMailer.new(exception)
      mailer.notify_if_deadlock_detected
      if mailer.deadlock_detected?
        requeue(voter_list_id, enabled)
      else
        raise exception
      end
    else
      requeue(voter_list_id, enabled)
    end
  end
end
