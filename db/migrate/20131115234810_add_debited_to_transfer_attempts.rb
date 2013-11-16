class AddDebitedToTransferAttempts < ActiveRecord::Migration
  def change
    add_column(:transfer_attempts, :debited, :boolean, default: false)
    TransferAttempt.connection.execute("update transfer_attempts set debited = true")
  end
end
