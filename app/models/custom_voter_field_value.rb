class CustomVoterFieldValue < ActiveRecord::Base
  belongs_to :custom_voter_field
  belongs_to :voter

  named_scope :voter_fields, lambda{|voter,field| { :conditions => ["voter_id = ? and custom_voter_field_id = ?", voter.id, field.id ] } }
  named_scope :for, lambda{|voter| { :conditions => ["voter_id = ? ", voter.id] } }
end
