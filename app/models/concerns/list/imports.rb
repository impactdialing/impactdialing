require 'set'
class MessagePackSet < Set
  def to_msgpack(*args)
    self.to_a.to_msgpack(*args)
  end
end

class List::Imports

private
  def setup_or_recover_results(results)
    @results = {
      saved_numbers:        0,
      total_numbers:        0,
      saved_leads:          0,
      total_leads:          0,
      new_numbers:          MessagePackSet.new,
      pre_existing_numbers: MessagePackSet.new,
      dnc_numbers:          MessagePackSet.new,
      cell_numbers:         MessagePackSet.new,
      new_leads:            0,
      updated_leads:        0,
      invalid_numbers:      MessagePackSet.new,
      invalid_rows:         [],
      use_custom_id:        false
    }

    if results
      @results = MessagePack.unpack(results)
      [
        :new_numbers, :pre_existing_numbers, :dnc_numbers,
        :cell_numbers, :invalid_numbers
      ].each do |set_name|
        @results[set_name] = MessagePackSet.new(@results[set_name])
      end
    end
  end
  
public
  def initialize(voter_list, csv_mapping, cursor=0, results=nil)
    @voter_list  = voter_list
    @csv_mapping = csv_mapping
    @cursor      = cursor
    setup_or_recover_results(results)
  end
end
