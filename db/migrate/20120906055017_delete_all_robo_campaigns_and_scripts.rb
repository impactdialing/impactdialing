class DeleteAllRoboCampaignsAndScripts < ActiveRecord::Migration
  def up
    Campaign.find_all_by_type('robo').each {|r| r.destroy}
    Script.find_all_by_robo(true).each {|s| s.destroy}
  end

  def down
  end
end
