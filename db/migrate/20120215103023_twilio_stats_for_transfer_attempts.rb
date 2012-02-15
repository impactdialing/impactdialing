class TwilioStatsForTransferAttempts < ActiveRecord::Migration
  
  def self.up
    add_column(:transfer_attempts, :tPrice, :float)
    add_column(:transfer_attempts, :tStatus, :string)
    add_column(:transfer_attempts, :tCallSegmentSid, :string)
    add_column(:transfer_attempts, :tAccountSid, :string)
    add_column(:transfer_attempts, :tCalled, :string)
    add_column(:transfer_attempts, :tCaller, :string)
    add_column(:transfer_attempts, :tPhoneNumberSid, :string)
    add_column(:transfer_attempts, :tStartTime, :datetime)
    add_column(:transfer_attempts, :tEndTime, :datetime)
    add_column(:transfer_attempts, :tDuration, :integer)
    add_column(:transfer_attempts, :tFlags, :integer)
    
  end

  def self.down
    remove_column(:transfer_attempts, :tPrice)
    remove_column(:transfer_attempts, :tStatus)
    remove_column(:transfer_attempts, :tCallSegmentSid)
    remove_column(:transfer_attempts, :tAccountSid)
    remove_column(:transfer_attempts, :tCalled)
    remove_column(:transfer_attempts, :tCaller)
    remove_column(:transfer_attempts, :tPhoneNumberSid)
    remove_column(:transfer_attempts, :tStartTime)
    remove_column(:transfer_attempts, :tEndTime)
    remove_column(:transfer_attempts, :tDuration)
    remove_column(:transfer_attempts, :tFlags)
  end
end
