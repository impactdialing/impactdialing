class CampaignAddRatio < ActiveRecord::Migration
  def self.up
    add_column :campaigns, :ratio_2, :integer, :default=>33
    add_column :campaigns, :ratio_3, :integer, :default=>20
    add_column :campaigns, :ratio_4, :integer, :default=>12
    add_column :campaigns, :ratio_override, :integer, :default=>0
    add_column :campaigns, :ending_window_method, :string, :default=>"Not used"
    remove_column :campaigns, :keypad_1
    remove_column :campaigns, :keypad_2
    remove_column :campaigns, :keypad_3
    remove_column :campaigns, :keypad_4
    remove_column :campaigns, :keypad_5
    remove_column :campaigns, :keypad_6
    remove_column :campaigns, :keypad_7
    remove_column :campaigns, :keypad_8
    remove_column :campaigns, :keypad_9
  end

  def self.down
    remove_column :campaigns, :ending_window_method
    remove_column :campaigns, :ratio_2
    remove_column :campaigns, :ratio_4
    remove_column :campaigns, :ratio_3
  end
end
