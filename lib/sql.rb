module Sql
  
  def id_find_in_batches (opts={}, &block)
    page_size = opts.delete(:page_size) || 500
    num_retries = opts.delete(:retry) || 0
    start_id = opts.delete(:start_id) || 0
    maxid = opts.delete(:end_id) || self.maximum(:id).to_i
    loop do
      last_id = start_id + page_size
      query_params = opts.merge({:conditions => ["id > ? and id <= ?", start_id, last_id]})
      self.all(query_params).each do |v|
        retry_count = 0
        begin
          yield(v) if block_given?
        rescue
          Rails.logger.error("Retrying on raised Exception #{$!}") if retry_count < num_retries
          retry_count += 1
          retry if retry_count < num_retries
        end
      end
      start_id = last_id
      break if (start_id >= maxid)
    end
  end
  
end