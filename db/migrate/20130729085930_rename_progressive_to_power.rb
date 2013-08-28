class RenameProgressiveToPower < ActiveRecord::Migration
  def up
    Campaign.all.each do |campaign|
      if(campaign.type == "Progressive")
        campaign.update_attributes(type: "Power")
      end
    end
  end

  def down
  end
end
