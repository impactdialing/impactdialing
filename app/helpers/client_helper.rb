module ClientHelper

  def callerInCampaign(c)
       if @campaign
          @campaign.callers.include?(c)
       else
         false
       end
    end



    def listInCampaign(c)
         if @campaign
            @campaign.voter_lists.include?(c)
         else
           false
         end
      end
    
end
