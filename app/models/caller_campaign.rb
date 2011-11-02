class CallerCampaign < ActiveRecord::Base
  set_table_name "callers_campaigns"
  belongs_to :campaign
  belongs_to :caller 
  
end