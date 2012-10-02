module BatchQuery
  

  module ClassMethods
    def find_all_in_batches(opts={}, &block)
      page_size = opts.delete(:page_size) || 100
      start_id = opts.delete(:start_id) || 0
      maxid = opts.delete(:end_id) || self.maximum(:id).to_i
      campaign_id = opts.delete(:campaign_id)
      order_by = opts.delete(:order_by)
      loop do
        last_id = start_id + page_size
        query_params = opts.merge({:conditions => ["campaign_id = ? and id > ? and id <= ?", campaign_id, start_id, last_id], :order=> order_by })
        self.all(query_params).each do |v|
          begin
            yield(v) if block_given?
          rescue
          end
        end
        start_id = last_id
        break if (start_id >= maxid)
      end
    end    
  end
  
  

  module InstanceMethods
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
  
end