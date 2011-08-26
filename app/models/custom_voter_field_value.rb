class CustomVoterFieldValue < ActiveRecord::Base
  belongs_to :custom_voter_field
  belongs_to :voter
  validates_presence_of :voter_id, :custom_voter_field_id

  named_scope :voter_fields, lambda{|voter,field| { :conditions => ["voter_id = ? and custom_voter_field_id = ?", voter.id, field.id ] } }
end
