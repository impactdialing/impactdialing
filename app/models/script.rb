class Script < ActiveRecord::Base

  include Deletable
  validates_presence_of :name
  validate :no_campaign_using_on_deletion
  validate :check_subscription_type_for_transfers
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

  def ability
    @ability ||= Ability.new(account)
  end

  def selected_fields
    unless voter_fields.nil?
      JSON.parse(voter_fields).select{ |field| VoterList::VOTER_DATA_COLUMNS.values.include?(field) }
    end
  end

  def transfer_types
    if ability.can? :add_transfer, self
      [Transfer::Type::WARM, Transfer::Type::COLD]
    else
      []
    end
  end

  def check_subscription_type_for_transfers
    transfers.each do |transfer|
      if !transfer_types.include?(transfer.transfer_type)
        errors.add(:base, 'Your subscription does not allow transfering calls in this mode.')
        return
      end
    end
  end



  def selected_custom_fields
    unless voter_fields.nil?
      JSON.parse(voter_fields).select{ |field| !VoterList::VOTER_DATA_COLUMNS.values.include?(field) }
    end
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
    if active_change == [true, false] && !campaigns.active.empty?
      errors.add(:base, I18n.t(:script_cannot_be_deleted))
    end
  end

  def questions_possible_responses
    questions.as_json({root: false})
  end

  def answers_recorded?
    answer_count = Question.question_count_script(self.id).values.inject { |a, b| a + b } || 0
    answer_count == 0
  end


  def as_json(options)
    json = super options.merge({
      :include => [
        :notes,
        :transfers,
        {
          :script_texts => {
            :except => [:content],
            :methods => [:markdown_content]
          }
        }
      ]
    })
    json["script"].merge({questions: questions_possible_responses})
  end


end
