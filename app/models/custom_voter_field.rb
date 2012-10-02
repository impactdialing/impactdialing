class CustomVoterField < ActiveRecord::Base
  belongs_to :account
  has_many :custom_voter_field_values
end
