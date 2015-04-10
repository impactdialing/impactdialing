module ImportProxy
  def import_hashes(hashes, options={})
    return if hashes.empty?

    klass = self

    Upsert.batch(klass.connection, klass.table_name) do |upsert|
      hashes.each do |hash|
        hash = HashWithIndifferentAccess.new(hash)

        if hash[:id]
          selector = {id: hash[:id]}
          if klass.column_names.include?('updated_at')
            hash[:updated_at] = Time.now.utc
          end
        else
          if klass.column_names.include?('created_at')
            hash[:created_at] = hash[:updated_at] = Time.now.utc
          end
          selector = hash
        end
        if (not options[:validate]) or (options[:validate] and klass.new(hash).valid?)
          upsert.row(selector, hash)
        end
      end
    end
  end
end