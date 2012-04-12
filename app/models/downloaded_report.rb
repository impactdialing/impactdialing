class DownloadedReport < ActiveRecord::Base
    belongs_to :user
    belongs_to :campaign
    
    
end