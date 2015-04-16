module ImportProxy
private
  def importing_update?(hash)
    hash[:id].present?
  end

  def setter(hash, columns_to_update=[])
    set_current_time = Proc.new do |hash, key_name|
      if self.column_names.include?(key_name.to_s)
        hash[key_name] = Time.now.utc
      end
    end

    if importing_update?(hash)
      set_current_time.call(hash, :updated_at)
    else
      set_current_time.call(hash, :created_at)
      set_current_time.call(hash, :updated_at)
    end

    if columns_to_update.empty?
      hash
    else
      columns_to_update.map!(&:to_s)
      hash.select{ |k,_| columns_to_update.include?(k.to_s) }
    end
  end

  def selector(hash)
    if importing_update?(hash)
      {id: hash[:id]}
    else
      hash
    end
  end

public
  def import_hashes(hashes, options={})
    return if hashes.empty?

    unless options.keys.include?(:validate)
      options[:validate] = true
    end

    unless options.keys.include?(:columns_to_update)
      options[:columns_to_update] = []
    else
      options[:columns_to_update] = [*options[:columns_to_update]]
    end

    Upsert.batch(self.connection, self.table_name) do |upsert|
      hashes.each do |hash|
        hash          = HashWithIndifferentAccess.new(hash)
        selector_hash = selector(hash)
        setter_hash   = setter(hash, options[:columns_to_update])
        
        if (not options[:validate]) or (options[:validate] and self.new(hash).valid?)
          upsert.row(selector_hash, setter_hash)
        end
      end
    end
  end
end
