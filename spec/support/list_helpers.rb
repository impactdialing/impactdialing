module ListHelpers
  def import_list(list, households)
    List::Imports.new(list).save([active_redis_key], households)
  end

  def disable_list(list)
    list.update_attributes!(enabled: false)
  end

  def enable_list(list)
    list.update_attributes!(enabled: true)
  end

  def stub_list_parser(parser_double, redis_key, household)
    allow(parser_double).to receive(:parse_file).and_yield([redis_key], household, 0, {})
    allow(List::Imports::Parser).to receive(:new){ parser_double }
  end
end
