class ChangeTypeToTransferType < ActiveRecord::Migration
  def self.up
    rename_column :transfers, :type, :transfer_type
  end

  def self.down
    rename_column :transfers, :transfer_type, :type
  end
end
