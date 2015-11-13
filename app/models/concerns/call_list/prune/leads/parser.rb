class CallList::Prune::Leads::Parser < CallList::Parser
  def id_index
    @id_index ||= csv_mapping.csv_index_for('custom_id')
  end

  def each_batch(&block)
    parse_file(with_phone: false) do |id_register_keys, data, cursor, results|
      key_id_pairs = []
      data.each_with_index do |datum,ii|
        id, csv_row, i = *datum
        key_id_pairs << [id, id_register_keys[ii]]
      end
      yield key_id_pairs, cursor, results
    end
  end
end
