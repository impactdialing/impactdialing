class DownloadedReport < ActiveRecord::Base
    belongs_to :user
    belongs_to :campaign
    
    
   def self.active_reports(campaign_id)
     DownloadedReport.find_all_by_campaign_id(campaign_id, :conditions => [ "(created_at > ?)", 12.hours.ago],:order => "created_at DESC")
   end
   
   def self.active_reports_count(campaign_id)
     DownloadedReport.count(:conditions => [ "campaign_id = ? AND (created_at > ?)", campaign_id, 12.hours.ago])
   end
   
   def self.accounts_active_report_count(campaign_ids)     
     DownloadedReport.select("campaign_id").where("campaign_id in (?) AND (created_at > ?)", campaign_ids, 12.hours.ago).group("campaign_id").count
   end
   
    
    
end