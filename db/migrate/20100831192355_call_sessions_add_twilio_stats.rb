class CallSessionsAddTwilioStats < ActiveRecord::Migration
  def self.up
    add_column :call_attempts, :tCallSegmentSid, :string
    add_column :call_attempts, :tAccountSid, :string
    add_column :call_attempts, :tCalled, :string
    add_column :call_attempts, :tCaller, :string
    add_column :call_attempts, :tPhoneNumberSid, :string
    add_column :call_attempts, :tStatus, :integer
    add_column :call_attempts, :tDuration, :integer
    add_column :call_attempts, :tFlags, :integer
    add_column :call_attempts, :tStartTime, :datetime
    add_column :call_attempts, :tEndTime, :datetime
    add_column :call_attempts, :tPrice, :float

    add_column :caller_sessions, :tCallSegmentSid, :string
    add_column :caller_sessions, :tAccountSid, :string
    add_column :caller_sessions, :tCalled, :string
    add_column :caller_sessions, :tCaller, :string
    add_column :caller_sessions, :tPhoneNumberSid, :string
    add_column :caller_sessions, :tStatus, :integer
    add_column :caller_sessions, :tDuration, :integer
    add_column :caller_sessions, :tFlags, :integer
    add_column :caller_sessions, :tStartTime, :datetime
    add_column :caller_sessions, :tEndTime, :datetime
    add_column :caller_sessions, :tPrice, :float
    
    
  end

  def self.down
    remove_column :call_attempts, :tCallSegmentSid
    remove_column :call_attempts, :tAccountSid
    remove_column :call_attempts, :tCalled
    remove_column :call_attempts, :tCaller
    remove_column :call_attempts, :tPhoneNumberSid
    remove_column :call_attempts, :tStatus
    remove_column :call_attempts, :tDuration
    remove_column :call_attempts, :tFlags
    remove_column :call_attempts, :tStartTime
    remove_column :call_attempts, :tEndTime
    remove_column :call_attempts, :tPrice

    remove_column :caller_sessions, :tCallSegmentSid
    remove_column :caller_sessions, :tAccountSid
    remove_column :caller_sessions, :tCalled
    remove_column :caller_sessions, :tCaller
    remove_column :caller_sessions, :tPhoneNumberSid
    remove_column :caller_sessions, :tStatus
    remove_column :caller_sessions, :tDuration
    remove_column :caller_sessions, :tFlags
    remove_column :caller_sessions, :tStartTime
    remove_column :caller_sessions, :tEndTime
    remove_column :caller_sessions, :tPrice
  end
end
