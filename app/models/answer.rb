##
# This class manages peristence for responses to multiple choice questions.
# Currently, response data is imported periodically via Voter#persist_answers.
#
# See also +Note+ and its cousin Voter#persist_notes.
class Answer < ActiveRecord::Base
  belongs_to :voter
  belongs_to :caller
  belongs_to :question
  belongs_to :possible_response
  belongs_to :campaign
  belongs_to :call_attempt

  scope :for, lambda{|question| where("question_id = #{question.id}")}
  scope :for_questions, lambda{|question_ids| where("question_id in (?) ", question_ids)}
  scope :within, lambda { |from, to| where(:created_at => from..to) }
  scope :with_campaign_id, lambda { |campaign_id| where(:campaign_id => campaign_id) }
  
  def self.question_ids(cam_id)
    Answer.where(campaign_id: cam_id).order(:question_id).uniq.pluck(:question_id)
  end
  
end

# ## Schema Information
#
# Table name: `answers`
#
# ### Columns
#
# Name                        | Type               | Attributes
# --------------------------- | ------------------ | ---------------------------
# **`id`**                    | `integer`          | `not null, primary key`
# **`voter_id`**              | `integer`          | `not null`
# **`question_id`**           | `integer`          | `not null`
# **`possible_response_id`**  | `integer`          | `not null`
# **`created_at`**            | `datetime`         |
# **`campaign_id`**           | `integer`          |
# **`caller_id`**             | `integer`          |
# **`call_attempt_id`**       | `integer`          |
#
# ### Indexes
#
# * `call_attempt_id`:
#     * **`call_attempt_id`**
#     * **`question_id`**
# * `index_answers_campaign_id_caller_id`:
#     * **`campaign_id`**
#     * **`caller_id`**
# * `index_answers_count_possible_response_campaign`:
#     * **`possible_response_id`**
#     * **`campaign_id`**
#     * **`caller_id`**
#     * **`created_at`**
# * `index_answers_on_campaign_created_at_possible_response`:
#     * **`campaign_id`**
#     * **`created_at`**
#     * **`possible_response_id`**
# * `index_answers_on_voter_id_and_question_id`:
#     * **`voter_id`**
#     * **`question_id`**
# * `index_distinct_question`:
#     * **`question_id`**
#     * **`campaign_id`**
#
