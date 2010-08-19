class CallerSession < ActiveRecord::Base
  belongs_to :caller, :class_name => "Caller", :foreign_key => "caller_id"
  belongs_to :campaign
  unloadable
end
