class RemoveUnnecesaryColumnsFromCampaign < ActiveRecord::Migration
  
  def self.up
    remove_column(:campaigns, :keypad_0)
    remove_column(:campaigns, :ratio_2)
    remove_column(:campaigns, :ratio_3)
    remove_column(:campaigns, :ratio_4)
    remove_column(:campaigns, :ending_window_method)
    remove_column(:campaigns, :caller_id_verified)
    remove_column(:campaigns, :max_calls_per_caller)
    remove_column(:campaigns, :use_web_ui)
  end

  def self.down
  end
end
