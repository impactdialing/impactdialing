class CustomVoterFieldValue < ActiveRecord::Base
  belongs_to :custom_voter_field
  belongs_to :voter
  validates_presence_of :voter_id, :custom_voter_field_id

  scope :voter_fields, lambda { |voter, field| {:conditions => ["voter_id = ? and custom_voter_field_id = ?", voter.id, field.id]} }
  scope :for, lambda { |voter| {:conditions => ["voter_id = ? ", voter.id]} }
  scope :for_field, lambda { |field| where("custom_voter_field_id = ?", field.id) }
  end
