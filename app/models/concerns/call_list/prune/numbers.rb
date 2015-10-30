class CallList::Prune::Numbers
  attr_reader :voter_list

  def initialize(voter_list)
    @voter_list = voter_list
  end

  def dial_queue
    @dial_queue ||= voter_list.campaign.dial_queue
  end

  def phone_number_set_keys
    [
      dial_queue.available.keys[:active],
      dial_queue.available.keys[:presented],
      dial_queue.completed.keys[:completed],
      dial_queue.completed.keys[:failed],
      dial_queue.blocked.keys[:blocked],
      dial_queue.recycle_bin.keys[:bin],
      voter_list.stats.key,
      voter_list.campaign.call_list.stats.key
    ]
  end

  def delete(numbers)
    Wolverine.list.delete_numbers({
      keys: phone_number_set_keys,
      argv: [numbers.to_json]
    })

    #Wolverine.list.delete_households({
    #  keys: [],
    #  argv: []
    #})
  end
end
