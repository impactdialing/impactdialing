class AddTransferTypeToTransferAttempt < ActiveRecord::Migration
  def self.up
    add_column(:transfer_attempts, :transfer_type, :string)
  end

  def self.down
    remove_column(:transfer_attempts, :transfer_type)
  end
end
