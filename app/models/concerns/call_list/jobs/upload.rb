class CallList::Jobs::Upload
  extend LibratoResque

  @queue = :import

  def self.perform(*args)
    @args_to_requeue = args

    begin
      perform_actual(*args)
    rescue Resque::TermException, Redis::BaseConnectionError => e
      Resque.enqueue(*args_to_requeue)
    end
  end

  # email can be nil when job is queued by system
  def self.mailer(voter_list, email=nil)
    unless email.nil?
      VoterListMailer.new(email, voter_list)
    end
  end
end
