class Note < ActiveRecord::Base
  validates_presence_of :note
  belongs_to :script
end
