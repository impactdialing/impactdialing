class DropFamilies < ActiveRecord::Migration
  def self.up
    drop_table :families
  end

  def self.down
  end
end
