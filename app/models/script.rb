class Script < ActiveRecord::Base

  include Deletable
  validates_presence_of :name
  validate :no_campaign_using_on_deletion
  belongs_to :account
  has_many :script_texts, :inverse_of => :script
  has_many :questions, :inverse_of => :script
  has_many :notes, :inverse_of => :script
  has_many :transfers
  has_many :campaigns
  accepts_nested_attributes_for :campaigns
  accepts_nested_attributes_for :script_texts, :allow_destroy => true
  accepts_nested_attributes_for :questions, :allow_destroy => true
  accepts_nested_attributes_for :notes, :allow_destroy => true
  accepts_nested_attributes_for :transfers, :allow_destroy => true

  scope :active, {:conditions => {:active => 1}}

  cattr_reader :per_page
  @@per_page = 25



  def selected_fields
    JSON.parse(voter_fields).select{ |field| VoterList::VOTER_DATA_COLUMNS.values.include?(field) } if voter_fields
  end

  def selected_custom_fields
    JSON.parse(voter_fields).select{ |field| !VoterList::VOTER_DATA_COLUMNS.values.include?(field) } if voter_fields
  end

  def selected_fields_json
    result = Hash.new
    selected_fields.try(:each) do |x|
      result[x+"_flag"] = true
    end
    result["Phone_flag"] = true
    result
  end

  def questions_and_responses
    questions.all(:include => [:possible_responses]).inject({}) do |acc, question|
      acc[question.text] = question.possible_responses.map(&:value)
      acc
    end
  end

  def no_campaign_using_on_deletion
    if active_change == [true, false] && !campaigns.empty?
      errors.add(:base, I18n.t(:script_cannot_be_deleted))
    end
  end

end
