class CallResponse < ActiveRecord::Base
  belongs_to :recording_response
  belongs_to :call_attempt
end
