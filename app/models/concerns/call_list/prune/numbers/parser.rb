class CallList::Prune::Numbers::Parser < CallList::Parser
  def each_batch(&block)
    parse_file do |household_keys, data, cursor, results|
      phones = []
      data.each do |datum|
        phone, csv_row, i = *datum
        phones << phone
      end
      yield phones, cursor, results
    end
  end
end
