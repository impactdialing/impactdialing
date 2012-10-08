class RemoveRedundantIndexesOnVoter < ActiveRecord::Migration
  def up
    remove_index :voters, name: 'index_voters_on_campaign_id'
    remove_index :voters, name: 'index_voters_on_Phone'
  end

  def down
    add_index :voters, [:campaign_id], :name => :index_voters_on_campaign_id
    add_index :voters, [:Phone], :name => :index_voters_on_Phone
  end
end
