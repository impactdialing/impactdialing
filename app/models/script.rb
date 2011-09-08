class Script < ActiveRecord::Base
  include Deletable
  validates_presence_of :name, :on => :create, :message => "can't be blank"
  belongs_to :user
  has_many :robo_recordings
  accepts_nested_attributes_for :robo_recordings, :allow_destroy => true

  default_scope :order => :name

  scope :robo, :conditions => {:robo => true }
  scope :manual, :conditions => {:robo => false }
  scope :active, {:conditions => {:active => 1}}

  after_find :set_result_set

  cattr_reader :per_page
  @@per_page = 25

  def set_result_set
    if self.result_set_1.blank?
      json={}
      for i in 1..49 do
        json["keypad_#{i}"] = self.send("keypad_#{i}")
      end
      self.result_set_1 = json.to_json
    end
  end

  def result_sets_used
    ret=[]
    for i in 1..NUM_RESULT_FIELDS do
				result_set = eval("self.result_set_#{i}")
				if result_set==nil
					json={}
				else
					json=JSON.parse(result_set)
				end

				ret << i if json.keys.length>0
		end
		ret
  end

  def notes_used
    ret=[]
    for i in 1..NUM_RESULT_FIELDS do
				note = eval("self.note_#{i}")
				if !note.blank?
				  ret << i
				end
		end
		ret
  end
end
