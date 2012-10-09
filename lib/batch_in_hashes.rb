module BatchInHashes
  extend ActiveSupport::Concern

  included do
    def find_in_hashes(options = {})
      options.assert_valid_keys(:start, :batch_size)

      relation = self
      conn = relation.klass.connection

      unless arel.orders.blank? && arel.taken.blank?
        ActiveRecord::Base.logger.warn("Scoped order and limit are ignored, it's forced to be batch order and batch size")
      end

      start = options.delete(:start) || 0
      batch_size = options.delete(:batch_size) || 1000

      relation = relation.reorder(batch_order).limit(batch_size)
      records = conn.execute(relation.where(table[primary_key].gteq(start)).to_sql).each(as: :hash)

      while records.any?
        records_size = records.size
        primary_key_offset = records.last["id"]

        yield records

        break if records_size < batch_size

        if primary_key_offset
          records = conn.execute(relation.where(table[primary_key].gt(primary_key_offset)).to_sql).each(as: :hash)
        else
          raise "Primary key not included in the custom select clause"
        end
      end
    end
  end
end
