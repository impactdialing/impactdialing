class Script < ActiveRecord::Base

  include Deletable
  validates_presence_of :name, :on => :create, :message => "can't be blank"
  belongs_to :account
  has_many :robo_recordings
  has_many :questions
  accepts_nested_attributes_for :questions, :allow_destroy => true
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

  def self.political_example(account)
    @rs={
      'keypad_1' => 'Strong supportive',
      'keypad_2' => 'Lean supportive',
      'keypad_3' => 'Undecided',
      'keypad_4' => 'Lean opposed',
      'keypad_5' => 'Strong opposed',
      'keypad_6' => 'Refused',
      'keypad_7' => 'Not home/call back',
      'keypad_8' => 'Language barrier',
      'keypad_9' => 'Wrong number',
      'name' => 'How supportive was the voter?'
    }
    Script.new(:name => 'Political Example Script', :note_1 => 'Email', :active => 1, :account_id => account.id, :result_set_1 => @rs.to_json).tap do |script|
      script.incompletes='{"5":[],"6":[],"1":["7"],"7":[],"2":[],"8":[],"3":[],"9":[],"4":[],"10":[]}'
      script.voter_fields='["CustomID","FirstName","MiddleName","LastName","Suffix","Age","Gender","Email"]'
      script.script = <<-EOS
Hi, is ___ there?

My name's ___ and I'm a volunteer with the such-and-such campaign.

I'm voting for such-and-such because...

Can we count on you to vote for such-and-such?
      EOS
    end
  end
end
