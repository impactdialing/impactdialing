class Family < ActiveRecord::Base
  belongs_to :voter, :class_name => "Voter", :foreign_key => "voter_id"
end
