class CustomVoterFieldValue < ActiveRecord::Base
  belongs_to :custom_voter_field
  belongs_to :voter
  validates_presence_of :voter_id, :custom_voter_field_id

  scope :voter_fields, lambda { |voter, field| where(voter_id: voter, custom_voter_field_id: field) }
  scope :for, lambda { |voter| {:conditions => ["voter_id = ? ", voter.id]} }
  scope :for_field, lambda { |field| where("custom_voter_field_id = ?", field.id) }
  end

# ## Schema Information
#
# Table name: `custom_voter_field_values`
#
# ### Columns
#
# Name                         | Type               | Attributes
# ---------------------------- | ------------------ | ---------------------------
# **`id`**                     | `integer`          | `not null, primary key`
# **`voter_id`**               | `integer`          |
# **`custom_voter_field_id`**  | `integer`          |
# **`value`**                  | `string(255)`      |
#
# ### Indexes
#
# * `index_custom_voter_field_values_on_voter_id`:
#     * **`voter_id`**
#
