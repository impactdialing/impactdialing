class DeleteAllRoboCampaignsAndScripts < ActiveRecord::Migration
  def up
    Campaign.find_all_by_type('robo').each {|r| r.destroy}
    if column_exists? :scripts, :robo
      Script.find_all_by_robo(true).each {|s| s.destroy}
    end    
  end

  def down
  end
end

class Robo < Campaign
end
