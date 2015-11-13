require 'resque/errors'
require 'librato_resque'

class CallList::Jobs::Prune
  extend LibratoResque

  @queue = :import

  def self.perform(voter_list_id, scope, email, cursor=0, results=nil)
    namespace    = "CallList::Prune::#{scope.capitalize}"
    voter_list   = VoterList.find voter_list_id
    pruner_klass = namespace.constantize
    pruner       = pruner_klass.new(voter_list, cursor, results)

    pruner.parse do |data|
      pruner.delete(data)
      cursor  = pruner.cursor
      results = pruner.results
    end

    final_results = pruner.final_results
    mailer(voter_list, email).try("pruned_#{scope}", final_results)
  end

  def self.mailer(voter_list, email)
    VoterListMailer.new(email, voter_list)
  end
end
