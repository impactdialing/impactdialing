class CustomVoterField < ActiveRecord::Base
  attr_accessible :name, :account, :account_id
  
  belongs_to :account
  has_many :custom_voter_field_values
end

# ## Schema Information
#
# Table name: `custom_voter_fields`
#
# ### Columns
#
# Name              | Type               | Attributes
# ----------------- | ------------------ | ---------------------------
# **`id`**          | `integer`          | `not null, primary key`
# **`name`**        | `string(255)`      | `not null`
# **`account_id`**  | `integer`          |
#
