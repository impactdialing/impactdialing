module FactoryGirlImportHelpers
  # Useful when inserting large number of records.
  # Bypasses validation and performs bulk INSERTs via
  # activerecord-import.
  def build_and_import_list(type, count, options={})
    create_list(type, count, options)
    # items = build_list(type, count, options)
    # klass = items.first.class
    # klass.import items
    # klass.all
  end

  # Useful when building a list via FactoryGirl's #build_list.
  # Takes a block that receives each item in the collection
  # and should return a set of options that will pass to FactoryGirl's
  # #build_list.
  def build_and_import_list_for_each(collection, type, count, &block)
    list = nil
    collection.each do |item|
      options = yield item
      list = create_list(type, count, options)
    end
    # items = lists.flatten
    klass = list.first.class
    # klass.import items
    klass.all
  end

  # Useful when building a list where each item should receive
  # a custom set of options.
  # Takes a block that receives nothing and should return
  # a set of options that will pass to FactoryGirl's #build.
  def build_and_import_sampled_list(type, count, &block)
    options = yield
    create_list(type, count, options)
    # items = []
    # count.times do
    #   options = yield
    #   items << build(type, options)
    # end
    # klass = items.first.class
    # klass.import items
    # klass.all
  end
end