class AddAbandonmentRateVariableToAccounts < ActiveRecord::Migration
  def self.up
    add_column(:accounts, :abandonment, :string)
  end

  def self.down
    remove_column(:accounts, :abandonment)
  end
end
