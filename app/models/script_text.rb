class ScriptText < ActiveRecord::Base
  attr_accessible :content, :script_id, :script_order

  validates :content, presence: true
  validates :script, presence: true
  validates :script_order, presence: true, numericality: true

  belongs_to :script
end
