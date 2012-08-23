class AddModeratorCampaign < ActiveRecord::Migration
    def self.up
       create_table :moderator_campaigns do |t|
         t.string :name
        end
    end

  def self.down
  end
end
